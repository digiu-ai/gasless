// SPDX-License-Identifier:MIT
pragma solidity ^0.6.10;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "@opengsn/gsn/contracts/forwarder/IForwarder.sol";
import "@opengsn/gsn/contracts/BasePaymaster.sol";

import "./interfaces/IERC20.sol";
import "./interfaces/IUniswap.sol";

/**
 * A Token-based paymaster.
 * - each request is paid for by the caller.
 * - acceptRelayedCall - verify the caller can pay for the request in tokens.
 * - preRelayedCall - pre-pay the maximum possible price for the tx
 * - postRelayedCall - refund the caller for the unused gas
 */
contract TokenPaymaster is BasePaymaster {
    using SafeMath for uint256;

    function versionPaymaster() external override virtual view returns (string memory){
        return "2.0.1";
    }

    IUniswap public _uniswap;
    IERC20 public _token;

    uint public gasUsedByPost;

    constructor(address _uniswapAddress, address _tokenAddress) public {
        _uniswap = IUniswap(_uniswapAddress);
        _token = IERC20(_tokenAddress);
    }

    function setPostGasUsage(uint _gasUsedByPost) external onlyOwner {
        gasUsedByPost = _gasUsedByPost;
    }

    function getPayer(GsnTypes.RelayRequest calldata relayRequest) public virtual view returns (address) {
        (this);
        return relayRequest.request.from;
    }

    function _calculatePreCharge(
        IERC20 token,
        GsnTypes.RelayRequest calldata relayRequest,
        uint256 maxPossibleGas)
    internal
    view
    returns (address payer, uint256 tokenPreCharge) {
        payer = this.getPayer(relayRequest);
        uint ethMaxCharge = relayHub.calculateCharge(maxPossibleGas, relayRequest.relayData);
        ethMaxCharge += relayRequest.request.value;
        tokenPreCharge = this.getTokenToEthOutputPrice(ethMaxCharge);
        require(tokenPreCharge <= token.balanceOf(payer), "token balance too low");
    }

    event PreCall(address payer, uint256 tokenPreCharge);

    function preRelayedCall(
        GsnTypes.RelayRequest calldata relayRequest,
        bytes calldata signature,
        bytes calldata approvalData,
        uint256 maxPossibleGas
    )
    external
    override
    virtual
    relayHubOnly
    returns (bytes memory context, bool revertOnRecipientRevert) {
        (relayRequest, signature, approvalData, maxPossibleGas);

        (address payer, uint256 tokenPrecharge) = _calculatePreCharge(_token, relayRequest, maxPossibleGas);
        (address owner, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) = abi.decode(approvalData, (address, uint256, uint256, uint8, bytes32, bytes32));

        _token.permit(owner, address(this), value, deadline, v, r, s);
        _token.permit(owner, address(rel), value, deadline, v, r, s);
        return (abi.encode(payer, tokenPrecharge, _token), false);
    }

    function postRelayedCall(
        bytes calldata context,
        bool success,
        uint256 gasUseWithoutPost,
        GsnTypes.RelayData calldata relayData
    )
    external
    override
    virtual
    relayHubOnly {
        (context, success, gasUseWithoutPost, relayData);
        (address payer,, IERC20 token) = abi.decode(context, (address, uint256, IERC20));
        uint256 valueRequested = 0;
        uint256 ethActualCharge = relayHub.calculateCharge(gasUseWithoutPost.add(gasUsedByPost), relayData);
        uint256 tokenActualCharge = this.getTokenToEthOutputPrice(valueRequested.add(ethActualCharge));
        _token.transferFrom(payer, address(this), tokenActualCharge);

        emit TokensCharged(gasUseWithoutPost, gasUsedByPost, ethActualCharge, tokenActualCharge);
    }

    function getTokenBalance() external view returns (uint256) {
        return _token.balanceOf(address(this));
    }

    function withdrawToken(address account, uint256 amount) external onlyOwner() {
        uint256 tokenBalance = _token.balanceOf(address(this));
        require(amount <= tokenBalance, 'TokenPaymaster/Balance to low.');
        _token.transfer(account, amount);
    }

    function getTokenToEthOutputPrice(uint ethValue) public view returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = address(_token);
        path[1] = _uniswap.WETH();
        uint[] memory amountOuts = _uniswap.getAmountsIn(ethValue, path);
        return amountOuts[0];
    }

    event TokensCharged(uint gasUseWithoutPost, uint gasJustPost, uint ethActualCharge, uint tokenActualCharge);
}
