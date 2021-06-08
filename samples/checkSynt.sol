pragma solidity ^0.6.0;



contract SynthCheckBridgeMock {

    function checkSynt (address synt) external  returns (bytes32 txID) {
         txID = keccak256(abi.encodePacked(this, requestCount));

        bytes memory out  = abi.encodeWithSelector(bytes4(keccak256(bytes('mintSyntheticToken(bytes32,address,uint256,address)'))), txID, synt, 15000000, msg.sender);

      (bool success, bytes memory data) = routeForCallback[correlationId].call(b);
      require(success && (data.length == 0 || abi.decode(data, (bool))), 'FAILED');

    }


}
