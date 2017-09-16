// PacioToken.sol 2017.08.22 started

// The Pacio Token named PIOE for the Ethereum version

// Following the EIP20 standard: https://github.com/ethereum/EIPs/blob/master/EIPS/eip-20-token-standard.md

pragma solidity ^0.4.15;

import "./EIP20Token.sol";

contract PacioToken is EIP20Token {
  // enum NFF {  // Founders/Foundation enum
  //   Founders, // 0 Pacio Founders
  //   Foundatn} // 1 Pacio Foundation
  string public constant name   = "Pacio Token";
  string public constant symbol = "PIOE";
  uint8  public constant decimals = 12;
  uint   public tokensIssued;           // Tokens issued - tokens in circulation
  uint   public tokensAvailable;        // Tokens available = total supply less allocated and issued tokens
  uint   public contributors;           // Number of contributors
  uint   public founderTokensAllocated; // Founder tokens allocated
  uint   public founderTokensVested;    // Founder tokens vested. Same as iTokensOwnedM[pFounderToksA] until tokens transferred. Unvested tokens = founderTokensAllocated - founderTokensVested
  uint   public foundationTokensAllocated; // Foundation tokens allocated
  uint   public foundationTokensVested;    // Foundation tokens vested. Same as iTokensOwnedM[pFoundationToksA] until tokens transferred. Unvested tokens = foundationTokensAllocated - foundationTokensVested
  bool   public icoCompleteB;           // Is set to true when both presale and full ICO are complete. Required for vesting of founder and foundation tokens and transfers of PIOEs to PIOs
  address private pFounderToksA;        // Address for Founder tokens issued
  address private pFoundationToksA;     // Address for Foundation tokens issued

  // Events
  // ------
  event LogIssue(address indexed Dst, uint Picos);
  event LogSaleCapReached(uint TokensIssued); // not tokensIssued just to avoid compiler Warning: This declaration shadows an existing declaration
  event LogIcoCompleted();
  event LogBurn(address Src, uint Picos);
  event LogDestroy(uint Picos);

  // Constructor not payable
  // -----------
  function PacioToken() {
    founderTokensAllocated    = 10**20; // 10% or 100 million = 1e20 Picos
    foundationTokensAllocated = 10**20; // 10% or 100 million = 1e20 Picos This call sets tokensAvailable
    Mint(10**21);                       // 1 Billion PIOEs    = 1e21 Picos, all minted)
  }

  // Initialisation/Settings Methods IsOwner but not IsActive
  // -------------------------------
  // Mint()
  // PacioICO() includes a Mint() fn to allow manual calling of this if necessary e.g. re full ICO going over the cap
  function Mint(uint picos) IsOwner {
    totalSupply           = add(totalSupply,           picos);
    iTokensOwnedM[ownerA] = add(iTokensOwnedM[ownerA], picos);
    tokensAvailable = subMaxZero(totalSupply, tokensIssued + founderTokensAllocated + foundationTokensAllocated);
    // From the EIP20 Standard: A token contract which creates new tokens SHOULD trigger a Transfer event with the _from address set to 0x0 when tokens are created.
    Transfer(0x0, ownerA, picos); // log event 0x0 from == minting
  }

  // PrepareForSale()
  // stops transfers and allows purchases
  function PrepareForSale() IsOwner {
    require (!icoCompleteB); // Cannot start selling again once ICO has been set to completed
    saleInProgressB = true;  // stops transfers
  }

  // Public Constant Methods
  // -----------------------
  // None. Used public variables instead which result in getter functions

  // State changing public methods made pause-able and with call logging
  // -----------------------------
  // Issue()
  // Transfers picos tokens to dst to issue them. IsOwner because this is expected to be called from the token sale contract
  function Issue(address dst, uint picos) IsOwner IsActive returns (bool) {
    require (saleInProgressB     // Sale is in progress
         && iTokensOwnedM[ownerA] >= picos // Owner has the tokens available
      // && picos > 0            // Non-zero issue No need to check for this
         && dst != address(this) // Not issuing to this token contract
         && dst != ownerA);      // Not issuing to the owner of this contract - the token sale contract
    if (iTokensOwnedM[dst] == 0)
      contributors++;
    iTokensOwnedM[ownerA] -= picos; // There is no need to check this for underflow via a sub() call given the iTokensOwnedM[ownerA] >= picos check
    iTokensOwnedM[dst]     = add(iTokensOwnedM[dst], picos);
    tokensIssued           = add(tokensIssued,       picos);
    tokensAvailable    = subMaxZero(tokensAvailable, picos); // subMaxZero() in case a sale goes over, only possible for full ICO, when cap is for all available tokens.
    LogIssue(dst, picos);                                    // If that should happen,may need to mint some more PIOEs to allow founder and foundation vesting to complete.
    return true;
  }

  // SaleCapReached()
  // To be be called from the token sale contract when a cap (pre or full) is reached
  // Allows transfers
  function SaleCapReached() IsOwner IsActive {
    saleInProgressB = false; // allows transfers
    LogSaleCapReached(tokensIssued);
  }

  // Functions for manual calling via same name function in PacioICO()
  // =================================================================
  // IcoCompleted()
  // To be be called manually via PacioICO after full ICO ends. Could be called before cap is reached if ....
  function IcoCompleted() IsOwner IsActive {
    require (!icoCompleteB);
    saleInProgressB = false; // allows transfers
    icoCompleteB    = true;
    LogIcoCompleted();
  }

  // SetFFSettings(address vFounderTokensA, address vFoundationTokensA, uint vFounderTokensAllocation, uint vFoundationTokensAllocation)
  // Allows setting Founder and Foundation addresses (or changing them if an appropriate transfer has been done)
  //  plus optionally changing the allocations which are set by the constructor, so that they can be varied post deployment if required re a change of plan
  // All values are optional - zeros can be passed
  // Must have been called with non-zero Founder and Foundation addresses before Founder and Foundation vesting can be done
  function SetFFSettings(address vFounderTokensA, address vFoundationTokensA, uint vFounderTokensAllocation, uint vFoundationTokensAllocation) IsOwner {
    if (vFounderTokensA    != address(0)) pFounderToksA    = vFounderTokensA;
    if (vFoundationTokensA != address(0)) pFoundationToksA = vFoundationTokensA;
    if (vFounderTokensAllocation > 0)    assert((founderTokensAllocated    = vFounderTokensAllocation)    >= founderTokensVested);
    if (vFoundationTokensAllocation > 0) assert((foundationTokensAllocated = vFoundationTokensAllocation) >= foundationTokensVested);
    tokensAvailable = totalSupply - founderTokensAllocated - foundationTokensAllocated - tokensIssued;
  }

  // VestFFTokens()
  // To vest Founder and/or Foundation tokens
  // 0 can be passed meaning skip that one
  // No separate event as the LogIssue event can be used to trace vesting transfers
  // To be be called manually via PacioICO
  function VestFFTokens(uint vFounderTokensVesting, uint vFoundationTokensVesting) IsOwner IsActive {
    require (icoCompleteB); // ICO must be completed before vesting can occur. djh?? Add other time restriction?
    if (vFounderTokensVesting > 0) {
      assert(pFounderToksA != address(0)); // Founders token address must have been set
      assert((founderTokensVested  = add(founderTokensVested,          vFounderTokensVesting)) <= founderTokensAllocated);
      iTokensOwnedM[ownerA]        = sub(iTokensOwnedM[ownerA],        vFounderTokensVesting);
      iTokensOwnedM[pFounderToksA] = add(iTokensOwnedM[pFounderToksA], vFounderTokensVesting);
      LogIssue(pFounderToksA,          vFounderTokensVesting);
      tokensIssued = add(tokensIssued, vFounderTokensVesting);
    }
    if (vFoundationTokensVesting > 0) {
      assert(pFoundationToksA != address(0)); // Foundation token address must have been set
      assert((foundationTokensVested  = add(foundationTokensVested,          vFoundationTokensVesting)) <= foundationTokensAllocated);
      iTokensOwnedM[ownerA]           = sub(iTokensOwnedM[ownerA],           vFoundationTokensVesting);
      iTokensOwnedM[pFoundationToksA] = add(iTokensOwnedM[pFoundationToksA], vFoundationTokensVesting);
      LogIssue(pFoundationToksA,       vFoundationTokensVesting);
      tokensIssued = add(tokensIssued, vFoundationTokensVesting);
    }
    // Does not affect tokensAvailable as these tokens had already been allowed for in tokensAvailable when allocated
  }

  // Burn()
  // For use when transferring issued PIOEs to PIOs
  // To be be called manually via PacioICO or from a new transfer contract to be written which is set to own this one
  function Burn(address src, uint picos) IsOwner IsActive {
    require (icoCompleteB);
    iTokensOwnedM[src] = subMaxZero(iTokensOwnedM[src], picos);
    tokensIssued       = subMaxZero(tokensIssued, picos);
    totalSupply        = subMaxZero(totalSupply,  picos);
    LogBurn(src, picos);
    // Does not affect tokensAvailable as these are issued tokens that are being burnt
  }

  // Destroy()
  // For use when transferring unissued PIOEs to PIOs
  // To be be called manually via PacioICO or from a new transfer contract to be written which is set to own this one
  function Destroy(uint picos) IsOwner IsActive {
    require (icoCompleteB);
    totalSupply     = subMaxZero(totalSupply,     picos);
    tokensAvailable = subMaxZero(tokensAvailable, picos);
    LogDestroy(picos);
  }

  // Fallback function
  // =================
  // No sending ether to this contract!
  // Not payable so trying to send ether will throw
  function() {
    revert(); // reject any attempt to access the token contract other than via the defined methods with their testing for valid access
  }
} // End PacioToken contract
