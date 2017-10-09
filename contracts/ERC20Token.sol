// ERC20Token.sol 2017.08.16 started

// 2017.10.07 isERC20Token changed to isEIP20Token

pragma solidity ^0.4.15;

import "./Owned.sol";
import "./DSMath.sol";

/*
ERC Token Standard #20 Interface
https://github.com/ethereum/EIPs/issues/20
https://github.com/frozeman/EIPs/blob/94bc4311e889c2c58c561c074be1483f48ac9374/EIPS/eip-20-token-standard.md
Using Dappsys naming style of 3 letter names: src, dst, guy, wad
*/

contract ERC20Token is Owned, DSMath {
  // Data
  bool public constant isEIP20Token = true; // Interface declaration
  uint public totalSupply;     // Total tokens minted
  bool public saleInProgressB; // when true stops transfers

  mapping(address => uint) internal iTokensOwnedM;                 // Tokens owned by an account
  mapping(address => mapping (address => uint)) private pAllowedM; // Owner of account approves the transfer of an amount to another account

  // ERC20 Events
  // ============
  // Transfer
  // Triggered when tokens are transferred.
  event Transfer(address indexed src, address indexed dst, uint wad);

  // Approval
  // Triggered whenever approve(address spender, uint wad) is called.
  event Approval(address indexed Sender, address indexed Spender, uint Wad);

  // ERC20 Methods
  // =============
  // Public Constant Methods
  // -----------------------
  // balanceOf()
  // Returns the token balance of account with address guy
  function balanceOf(address guy) public constant returns (uint) {
    return iTokensOwnedM[guy];
  }

  // allowance()
  // Returns the number of tokens approved by guy that can be transferred ("spent") by spender
  function allowance(address guy, address spender) public constant returns (uint) {
    return pAllowedM[guy][spender];
  }

  // Modifier functions
  // ------------------
  modifier IsTransferOK(address src, address dst, uint wad) {
    require(!saleInProgressB          // Sale not in progress
         && !pausedB                  // IsActive
         && iTokensOwnedM[src] >= wad // Source has the tokens available
      // && wad > 0                   // Non-zero transfer No! The std says: Note Transfers of 0 values MUST be treated as normal transfers and fire the Transfer event
         && dst != src                // Destination is different from source
         && dst != address(this)      // Not transferring to this token contract
         && dst != ownerA);           // Not transferring to the owner of this contract - the token sale contract
    _;
  }

  // State changing public methods made pause-able and with call logging
  // -----------------------------
  // transfer()
  // Transfers wad of sender's tokens to another account, address dst
  // No need for overflow check given that totalSupply is always far smaller than max uint
  function transfer(address dst, uint wad) IsTransferOK(msg.sender, dst, wad) returns (bool) {
    iTokensOwnedM[msg.sender] -= wad; // There is no need to check this for underflow via a sub() call given the IsTransferOK iTokensOwnedM[src] >= wad check
    iTokensOwnedM[dst] = add(iTokensOwnedM[dst], wad);
    Transfer(msg.sender, dst, wad);
    return true;
  }

  // transferFrom()
  // Sender transfers wad tokens from src account src to dst account, if
  // sender had been approved by src for a transfer of >= wad tokens from src's account
  // by a prior call to approve() with that call's sender being this calls src,
  //  and its spender being this call's sender.
  function transferFrom(address src, address dst, uint wad) IsTransferOK(src, dst, wad) returns (bool) {
    require(pAllowedM[src][msg.sender] >= wad); // Transfer is approved
    iTokensOwnedM[src]         -= wad; // There is no need to check this for underflow given the require above
    pAllowedM[src][msg.sender] -= wad; // There is no need to check this for underflow given the require above
    iTokensOwnedM[dst] = add(iTokensOwnedM[dst], wad);
    Transfer(src, dst, wad);
    return true;
  }

  // approve()
  // Approves the passed address (of spender) to spend up to wad tokens on behalf of msg.sender,
  //  in one or more transferFrom() calls
  // If this function is called again it overwrites the current allowance with wad.
  function approve(address spender, uint wad) IsActive returns (bool) {
    // To change the approve amount you first have to reduce the addresses`
    //  allowance to zero by calling `approve(spender, 0)` if it is not
    //  already 0 to mitigate the race condition described here:
    //  https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
    // djh: This appears to be of doubtful value, and is not used in the Dappsys library though it is in the Zeppelin one. Removed.
    // require((wad == 0) || (pAllowedM[msg.sender][spender] == 0));
    pAllowedM[msg.sender][spender] = wad;
    Approval(msg.sender, spender, wad);
    return true;
  }
} // End ERC20Token contracts
