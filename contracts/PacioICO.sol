// PacioICO.sol 2017.08.16 started

/* Token sale for Pacio.io

Works with PacioToken.sol as the contract for the Pacio Token

The contract is intended to handle both presale and full ICO, though, if necessary a new contract could be used for the full ICO, with the token contract unchanged apart from its owner.

Min purchase Ether 0.1
No end date - just cap or pause

Decisions
---------
No threshold

2017.10.07 Removed ForwardFunds() and made forward happen on each receipt
           Changed from use of fallback fn to specific Buy() fn and made fallback revert, re best practices re fallback fn use.
           Since fallback functions can be misused or abused, Vitalik Buterin suggested "establishing as a convention that fallback functions should generally not be used except in very specific cases."
2017.10.08 Changed to deploy PacioToken contract directly rather than create it via the constructor here, and then to pass the address to  PrepareToStart() as part of getting Etherscan te recognise the Token contract

*/

pragma solidity ^0.4.15;

import "./PacioToken.sol"; // which imports Owned.sol, DSMath.sol, ERC20Token.sol

contract PacioICO is Owned, DSMath {
  string public name;         // Contract name
  uint public  startTime;     // start time of the sale
  uint public  picosCap;      // Cap for the sale
  uint public  picosSold;     // Cumulative Picos sold which should == PIOE.pTokensIssued
  uint public  picosPerEther; // 3,000,000,000,000,000 for ETH = $300 and target PIOE price = $0.10
  uint public  weiRaised;     // cumulative wei raised
  PacioToken public PIOE;     // the Pacio token contract
  address private pPCwalletA; // address of the Pacio Core wallet to receive funds raised

  // Constructor not payable
  // -----------
  //
  function PacioICO() {
    pausedB = true; // start paused
  }

  // Events
  // ------
  event LogPrepareToStart(string Name, uint StartTime, uint PicosCap, PacioToken TokenContract, address PCwallet);
  event LogSetPicosPerEther(uint PicosPerEther);
  event LogChangePCWallet(address PCwallet);
  event LogSale(address indexed Purchaser, uint SaleWei, uint Picos);
  event LogAllocate(address indexed Supplier, uint SuppliedWei, uint Picos);
  event LogSaleCapReached(uint WeiRaised, uint PicosSold);

  // PrepareToStart()
  // --------------
  // To be called manually by owner just prior to the start of the presale or the full ICO
  // Can also be called by owner to adjust settings. With care!!
  function PrepareToStart(string vNameS, uint vStartTime, uint vPicosCap, uint vPicosPerEther, PacioToken vTokenA, address vPCwalletA) IsOwner {
    require(vTokenA != address(0)
         && vPCwalletA != address(0));
    name       = vNameS;     // Pacio Presale | Pacio Token Sale
    startTime  = vStartTime;
    picosCap   = vPicosCap;  // Cap for the sale, 20 Million PIOEs = 20,000,000,000,000,000,000 = 20**19 Picos for the Presale
    PIOE       = vTokenA;    // The token contract
    pPCwalletA = vPCwalletA; // Pacio Code wallet to receive funds
    pausedB    = false;
    PIOE.PrepareForSale();   // stops transfers
    LogPrepareToStart(vNameS, vStartTime, vPicosCap, vTokenA, vPCwalletA);
    SetPicosPerEther(vPicosPerEther);
  }

  // Public Constant Methods
  // -----------------------
  // None. Used public variables instead which result in getter functions

  // State changing public method made pause-able
  // ----------------------------

  // Buy()
  // Fn to be called to buy PIOEs
  function Buy() payable IsActive {
    require(now >= startTime);       // sale is running (in conjunction with the IsActive test)
    require(msg.value >= 0.1 ether); // sent >= the min
    uint picos = mul(picosPerEther, msg.value) / 10**18; // Picos = Picos per ETH * Wei / 10^18 <=== calc for integer arithmetic as in Solidity
    weiRaised = add(weiRaised, msg.value);
    pPCwalletA.transfer(this.balance); // throws on failure
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
  // SetPicosPerEther()
  // Fn to be called daily (hourly?) or on significant Ether price movement to set the Pico price
  function SetPicosPerEther(uint vPicosPerEther) IsOwner {
    picosPerEther = vPicosPerEther; // 3,000,000,000,000,000 for ETH = $300 and target PIOE price = $0.10
    LogSetPicosPerEther(picosPerEther);
  }

  // ChangePCWallet()
  // Fn to be called to change the PC Wallet to receive funds raised. This is set initially via PrepareToStart()
  function ChangePCWallet(address vPCwalletA) IsOwner {
    require(vPCwalletA != address(0));
    pPCwalletA = vPCwalletA;
    LogChangePCWallet(vPCwalletA);
  }

  // Allocate()
  // Allocate in lieu for goods or services or fiat supplied valued at wad wei in return for picos issued. Not payable
  // no picosCap check
  // wad is only for logging
  function Allocate(address vSupplierA, uint wad, uint picos) IsOwner IsActive {
     PIOE.Issue(vSupplierA, picos);
    LogAllocate(vSupplierA, wad, picos);
    picosSold += picos; // ok wo overflow protection as PIOE.Issue() would have thrown on overflow
  }

  // Token Contract Functions to be called Manually via Owner calls to ICO Contract
  // ==============================================================================
  // ChangeTokenContractOwner()
  // To be called manually if a new sale contract is deployed to change the owner of the PacioToken contract to it.
  // Expects the sale contract to have been paused
  // Calling ChangeTokenContractOwner() will stop calls from the old sale contract to token contract IsOwner functions from working
  function ChangeTokenContractOwner(address vNewOwnerA) IsOwner {
    require(pausedB);
    PIOE.ChangeOwner(vNewOwnerA);
  }

  // PauseTokenContract()
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

  // Fallback function
  // =================
  // No sending ether to this contract!
  // Not payable so trying to send ether will throw
  function() {
    revert(); // reject any attempt to access the token contract other than via the defined methods with their testing for valid access
  }

} // End PacioICO contract

