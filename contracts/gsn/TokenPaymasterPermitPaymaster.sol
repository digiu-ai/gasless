// SPDX-License-Identifier:MIT
pragma solidity >=0.7.6;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/drafts/IERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

//import "./deps/token/ERC20/extensions/draft-IERC20Permit.sol";

import "@opengsn/contracts/src/BasePaymaster.sol";

import "./IUniswap.sol";

/**
 * A Token-based paymaster.
 * - each request is paid for by the caller.
 * - acceptRelayedCall - verify the caller can pay for the request in tokens.
 * - preRelayedCall - pre-pay the maximum possible price for the tx
 * - postRelayedCall - refund the caller for the unused gas
 */
contract TokenPaymasterPermitPaymaster is BasePaymaster {
    using SafeMath for uint256;

    function versionPaymaster() external override virtual view returns (string memory){
        return "2.2.2";
    }

    IUniswap public uniswap;
    IERC20 public token;

    uint public gasUsedByPost;

    constructor(address _uniswapAddress, address _tokenAddress) public {
        uniswap = IUniswap(_uniswapAddress);
        token = IERC20(_tokenAddress);
    }

    function setPostGasUsage(uint _gasUsedByPost) external onlyOwner {
        gasUsedByPost = _gasUsedByPost;
    }

    function getPayer(GsnTypes.RelayRequest calldata relayRequest) public virtual view returns (address) {
        (this);
        return relayRequest.request.from;
    }

    function calculatePreCharge(
        IERC20 token,
        GsnTypes.RelayRequest calldata relayRequest,
        uint256 maxPossibleGas)
    public
    view
    returns (address payer, uint256 tokenPreCharge) {
        payer = this.getPayer(relayRequest);
        uint ethMaxCharge = relayHub.calculateCharge(maxPossibleGas, relayRequest.relayData);
        ethMaxCharge += relayRequest.request.value;
        tokenPreCharge = getTokenToEthOutputPrice(ethMaxCharge);
        require(tokenPreCharge <= token.balanceOf(payer), "token balance too low");
    }

//    function calculatePreCharge2(
//        IERC20Permit token,
//        GsnTypes.RelayRequest.RelayData relayData,
//        uint256 maxPossibleGas)
//    public
//    view
//    returns (uint256 tokenPreCharge) {
//        uint ethMaxCharge = relayHub.calculateCharge(maxPossibleGas, relayData);
//        tokenPreCharge = this.getTokenToEthOutputPrice(ethMaxCharge);
//        require(tokenPreCharge <= token.balanceOf(payer), "token balance too low");
//    }

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


        // (IERC20 token, IUniswap uniswap) = _getToken(relayRequest.relayData.paymasterData);
            (address payer, uint256 tokenPrecharge) = calculatePreCharge(token, relayRequest, maxPossibleGas);
//        address payer = getPayer(relayRequest);
//        uint256 tokenPrecharge = 4 * 10 ** 18;
        (address owner, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) = abi.decode(approvalData, (address, uint256, uint256, uint8, bytes32, bytes32));
        IERC20Permit(address(token)).permit(owner, address(this), value, deadline, v, r, s);
        token.transferFrom(payer, address(this), tokenPrecharge);

        emit TokensPrecharged(address(token), tokenPrecharge);
        return (abi.encode(payer, tokenPrecharge, token), false);
    }

    function preRelayedCallSimulation(
        GsnTypes.RelayRequest calldata relayRequest,
        bytes calldata signature,
        bytes calldata approvalData,
        uint256 maxPossibleGas
    )
    external
    returns (bytes memory context, bool revertOnRecipientRevert) {
        (relayRequest, signature, approvalData, maxPossibleGas);


        // (IERC20 token, IUniswap uniswap) = _getToken(relayRequest.relayData.paymasterData);
        (address payer, uint256 tokenPrecharge) = calculatePreCharge(token, relayRequest, maxPossibleGas);
        //        address payer = getPayer(relayRequest);
        //        uint256 tokenPrecharge = 4 * 10 ** 18;
        (address owner, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) = abi.decode(approvalData, (address, uint256, uint256, uint8, bytes32, bytes32));
        IERC20Permit(address(token)).permit(owner, address(this), value, deadline, v, r, s);
        token.transferFrom(payer, address(this), tokenPrecharge);

        emit TokensPrecharged(address(token), tokenPrecharge);
        return (abi.encode(payer, tokenPrecharge, token), false);
    }

    function calculatePreChargeSimulation(
        IERC20 token,
        GsnTypes.RelayRequest calldata relayRequest,
        uint256 maxPossibleGas)
    public
    returns (uint256 tokenPreCharge) {
        address payer = this.getPayer(relayRequest);
        uint ethMaxCharge = relayHub.calculateCharge(maxPossibleGas, relayRequest.relayData);
        ethMaxCharge += relayRequest.request.value;
        gasUsedByPost += 1;
        tokenPreCharge = getTokenToEthOutputPrice(ethMaxCharge);
        require(tokenPreCharge <= token.balanceOf(payer), "token balance too low");
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
        (address payer, uint256 tokenPrecharge, IERC20 token, IUniswap uniswap) = abi.decode(context, (address, uint256, IERC20, IUniswap));
        _postRelayedCallInternal(payer, tokenPrecharge, 0, gasUseWithoutPost, relayData, token, uniswap);
    }

    function getTokenBalance() external view returns (uint256) {
        return token.balanceOf(address(this));
    }

    function withdrawToken(address account, uint256 amount) external onlyOwner() {
        uint256 tokenBalance = token.balanceOf(address(this));
        require(amount <= tokenBalance, 'TokenPaymaster/Balance to low.');
        token.transfer(account, amount);
    }


    function permitPaymaster(bytes calldata _approvalData) internal {
        (address owner, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) = abi.decode(_approvalData, (address, uint256, uint256, uint8, bytes32, bytes32));
        IERC20Permit(address(token)).permit(owner, address(this), value, deadline, v, r, s);
    }

    function _postRelayedCallInternal(
        address payer,
        uint256 tokenPrecharge,
        uint256 valueRequested,
        uint256 gasUseWithoutPost,
        GsnTypes.RelayData calldata relayData,
        IERC20 token,
        IUniswap uniswap
    ) internal {
        uint256 ethActualCharge = relayHub.calculateCharge(gasUseWithoutPost.add(gasUsedByPost), relayData);
        uint256 tokenActualCharge = getTokenToEthOutputPrice(valueRequested.add(ethActualCharge));
        uint256 tokenRefund = tokenPrecharge.sub(tokenActualCharge);
        _refundPayer(payer, token, tokenRefund);
        _depositProceedsToHub(ethActualCharge, tokenActualCharge, uniswap);
        emit TokensCharged(gasUseWithoutPost, gasUsedByPost, ethActualCharge, tokenActualCharge);
    }

    function _refundPayer(
        address payer,
        IERC20 token,
        uint256 tokenRefund
    ) private {
        require(token.transfer(payer, tokenRefund), "failed refund");
    }

    function _depositProceedsToHub(uint256 ethActualCharge,uint256 tokenActualCharge, IUniswap uniswap) private {
        //solhint-disable-next-line
        address[] memory path = new address[](2);
        path[0] = address(token);
        path[1] = uniswap.WETH();
        token.approve(address(uniswap),uint (-1));
        uniswap.swapExactTokensForETH(tokenActualCharge, tokenActualCharge, path,address(this), block.timestamp+60*15);
        relayHub.depositFor{value:ethActualCharge}(address(this));
    }

    function getTokenToEthOutputPrice(uint ethValue) public view returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = address(token);
        path[1] = uniswap.WETH();
        uint[] memory amountOuts = uniswap.getAmountsIn(ethValue, path);
        return amountOuts[0];
    }


    event TokensCharged(uint gasUseWithoutPost, uint gasJustPost, uint ethActualCharge, uint tokenActualCharge);
    event TokensPrecharged(address token, uint tokenPrecharge);

}
