// PacioICO.sol 2017.08.16 started

/* Token sale for Pacio.io

Works with PacioToken.sol as the contract for the Pacio Token

The contract is intended to handle both presale and full ICO, though, if necessary a new contract could be used for the full ICO, with the token contract unchanged apart from its owner.

Min purchase Ether 0.1
No end date - just cap or pause

Decisions
---------
No auto transfer to wallet. Allow funds to accumulate in this contract and be transferred out to the Pacio walltet by the owner calling ForwardFunds(address vWalletA)

No threshold

Will need some Ether in an account to cover deployment gas cost and the cost of running functions manually including ForwardFunds()


*/

pragma solidity ^0.4.15;

import "./PacioToken.sol"; // which imports Owned.sol, DSMath.sol, EIP20Token.sol

contract PacioICO is Owned, DSMath {
  string public name;
  uint public startTime;     // start time of the sale
  uint public picosCap;      // Cap for the sale
  uint public picosSold;     // Cumulative Picos sold which should == PIOE.pTokensIssued
  uint public picosPerEther; // 3,000,000,000,000,000 for ETH = $300 and target PIOE price = $0.10
  uint public weiRaised;     // cumulative wei raised
  PacioToken public PIOE;    // the token contract


  // Constructor not payable
  // -----------
  //
  function PacioICO() {
    PIOE    = new PacioToken(); // Deploy the token contract, owned by this contract. If a second contract is used for the full ICO, the address of the
    pausedB = true; // start paused
  }

  // Events
  // ------
  event LogPrepareToStart(string Name, uint StartTime, uint PicosCap);
  event LogPicosPerEther(uint PicosPerEther);
  event LogSale(address indexed Purchaser, uint SaleWei, uint Picos);
  event LogAllocate(address indexed Supplier, uint SuppliedWei, uint Picos);
  event LogSaleCapReached(uint WeiRaised, uint PicosSold);

  // PrepareToStart()
  // To be called manually by owner just prior to the start of the presale or the full ICO
  function PrepareToStart(string vNameS, uint vStartTime, uint vPicosCap, uint vPicosPerEther) IsOwner {
    name      = vNameS;            // Pacio Presale | Pacio Token Sale
    startTime = vStartTime;
    picosCap  = vPicosCap;         // Cap for the sale, 10 Million PIOEs = 10,000,000,000,000,000,000 = 10**19 Picos for the Presale
    PIOE.PrepareForSale(); // stops transfers
    pausedB  = false;
    LogPrepareToStart(vNameS, vStartTime, vPicosCap);
    SetPicosPerEther(vPicosPerEther);
  }

  // SetPicosPerEther()
  // Fn to be called daily (hourly?) or on significant Ether price movement to set the Pico price
  function SetPicosPerEther(uint vPicosPerEther) IsOwner {
    picosPerEther = vPicosPerEther; // 3,000,000,000,000,000 for ETH = $300 and target PIOE price = $0.10
    LogPicosPerEther(picosPerEther);
  }


  // Public Constant Methods
  // -----------------------
  // None. Used public variables instead which result in getter functions

  // State changing public methods made pause-able
  // -----------------------------

  // Fallback buys
  // Will need more than the default gas to run
  function () payable IsActive {
    require (now >= startTime);       // sale is running (in conjunction with the IsActive test)
    require (msg.value >= 0.1 ether); // sent >= the min
    uint picos = mul(picosPerEther, msg.value) / 10**18; // Picos = Picos per ETH * Wei / 10^18 <=== calc for integer arithmetic as in Solidity
    weiRaised = add(weiRaised, msg.value);
    PIOE.Issue(msg.sender, picos);
    LogSale(msg.sender, msg.value, picos);
    picosSold += picos; // ok wo overflow protection as PIOE.Issue() would have thrown on overflow
    if (picosSold >= picosCap) {
      // Cap reached so end the sale
      pausedB = true;
      PIOE.SaleCapReached(); // Allows transfers
      LogSaleCapReached(weiRaised, picosSold);
    }
  }

  // Functions to be called Manually
  // ===============================
  // ChangeTokenContractOwner()
  // To be called manually if a new sale contract is deployed to change the owner of the PacioToken contract to it.
  // Expects the sale contract to have been paused
  // Calling ChangeTokenContractOwner() will stop calls from the old sale contract to token contract IsOwner functions from working
  function ChangeTokenContractOwner(address vNewOwnerA) IsOwner {
    require(pausedB);
    PIOE.ChangeOwner(vNewOwnerA);
  }

  // PauseTokenContract()`
  // To be called manually to pause the token contract
  function PauseTokenContract() IsOwner {
    PIOE.Pause();
  }

  // ResumeTokenContract()
  // To be called manually to resume the token contract
  function ResumeTokenContract() IsOwner {
    PIOE.Resume();
  }

  // Mint()
  // To be called manually if necessary e.g. re full ICO going over the cap
  // Expects the sale contract to have been paused
  function Mint(uint picos) IsOwner {
    require(pausedB);
    PIOE.Mint(picos);
  }

  // IcoCompleted()
  // To be be called manually after full ICO ends. Could be called before cap is reached if ....
  // Expects the sale contract to have been paused
  function IcoCompleted() IsOwner {
    require(pausedB);
    PIOE.IcoCompleted();
  }

  // Allocate()
  // Allocate in lieu for goods or services supplied valued at wad wei in return for picos issued. Not payable
  // no picosCap check
  function Allocate(address vSupplierA, uint wad, uint picos) IsOwner IsActive {
     PIOE.Issue(vSupplierA, picos);
    LogAllocate(vSupplierA, wad, picos);
    picosSold += picos; // ok wo overflow protection as PIOE.Issue() would have thrown on overflow
  }

  // ForwardFunds()
  // Send contract balance to the passed fund collection wallet
  // Allow owner to do this even if not active
  function ForwardFunds(address vWalletA) IsOwner {
    require (this.balance > 0);
    vWalletA.transfer(this.balance); // throws on failure
  }

  // SetFFSettings()
  // Allows setting Founder and Foundation addresses (or changing them if an appropriate transfer has been done)
  //  plus optionally changing the allocations which are set by the PacioToken constructor, so that they can be varied post deployment if required re a change of plan
  // All values are optional - zeros can be passed
  // Must have been called with non-zero Founder and Foundation addresses before Founder and Foundation vesting can be done
  function SetFFSettings(address vFounderTokensA, address vFoundationTokensA, uint vFounderTokensAllocation, uint vFoundationTokensAllocation) IsOwner {
    PIOE.SetFFSettings(vFounderTokensA, vFoundationTokensA, vFounderTokensAllocation, vFoundationTokensAllocation);
  }

  // VestFFTokens()
  // To vest Founder and/or Foundation tokens
  // 0 can be passed meaning skip that one
  // SetFFSettings() must have been called with non-zero Founder and Foundation addresses before this fn can be used
  function VestFFTokens(uint vFounderTokensVesting, uint vFoundationTokensVesting) IsOwner {
    PIOE.VestFFTokens(vFounderTokensVesting, vFoundationTokensVesting);
  }

  // Burn()
  // For use when transferring issued PIOEs to PIOs
  // To be replaced by a new transfer contract to be written which is set to own the PacioToken contract
  function Burn(address src, uint picos) IsOwner {
    PIOE.Burn(src, picos);
  }

  // Destroy()
  // For use when transferring unissued PIOEs to PIOs
  // To be replaced by a new transfer contract to be written which is set to own the PacioToken contract
  function Destroy(uint picos) IsOwner {
    PIOE.Destroy(picos);
  }

} // End PacioToken contract

