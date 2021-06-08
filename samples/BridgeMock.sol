pragma solidity ^0.6.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./IBridge.sol";


// for testing on single chain
contract BridgeMock is IBridge, Ownable {

 uint256 public _id = 1000 ;

    mapping(uint256 => bytes) public callFunction;
    mapping(uint256 => address) public callers;


  function transmitRequest(bytes memory  _selector, address receiveSide)
    public
    override
    /*onlyOwner | onlyPortalOrSynthesis*/
    returns (bytes32 requestId)
  {

    _id = _id + 1;
    requestId = bytes32(_id); // чтобы не менять интерфейс


    callFunction[_id] = _selector;
    callers[_id] = receiveSide;

  }


    // SECOND CHAIN
  function oracleCall(uint256 requestId) external {
        bytes memory out  = callFunction[requestId];
        address caller = callers[requestId];
        caller.call(out);
  }

}

