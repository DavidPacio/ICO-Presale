/* Owned.sol

2017.03.04 Originally created. On 72nd birthday!!
2017.08.16 Brought into use for Pacio token sale use
2017.08.22 Logging of

Owned is a Base Contract for contracts that are:
• "owned"
• can have their owner changed by a call to ChangeOwner() by the owner
• can be paused  from an active state by a call to Pause() by the owner
• can be resumed from a paused state by a call to Resume() by the owner

Modifier functions available for use here and in child contracts are:
• IsOwner()  which throws if called by other than the current owner
• IsActive() which throws if called when the contract is paused

Changes of owner are logged via event LogOwnerChange(address indexed previousOwner, address newOwner)

*/

pragma solidity ^0.4.15;

contract Owned {
  address public ownerA; // Contract owner
  bool    public pausedB;

  // Constructor NOT payable
  // -----------
  function Owned() {
    ownerA = msg.sender;
  }

  // Modifier functions
  // ------------------
  modifier IsOwner {
    require(msg.sender == ownerA);
    _;
  }

  modifier IsActive {
    require(!pausedB);
    _;
  }

  // Events
  // ------
  event LogOwnerChange(address indexed PreviousOwner, address NewOwner);
  event LogPaused();
  event LogResumed();

  // State changing public methods
  // -----------------------------
  // Change owner
  function ChangeOwner(address vNewOwnerA) IsOwner {
    require(vNewOwnerA != address(0)
         && vNewOwnerA != ownerA);
    LogOwnerChange(ownerA, vNewOwnerA);
    ownerA = vNewOwnerA;
  }

  // Pause
  function Pause() IsOwner {
    pausedB = true; // contract has been paused
    LogPaused();
  }

  // Resume
  function Resume() IsOwner {
    pausedB = false; // contract has been resumed
    LogResumed();
  }
} // End Owned contract

