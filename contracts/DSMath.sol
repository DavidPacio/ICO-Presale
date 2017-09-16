// DSMath.sol
// From https://dappsys.readthedocs.io/en/latest/ds_math.html

// Reduced version - just the fns used by Pacio

// Copyright (C) 2015, 2016, 2017  DappHub, LLC

// Licensed under the Apache License, Version 2.0 (the "License").
// You may not use this file except in compliance with the License.

// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND (express or implied).

pragma solidity ^0.4.15;

contract DSMath {
  /*
  standard uint256 functions
  */

  function add(uint256 x, uint256 y) constant internal returns (uint256 z) {
    assert((z = x + y) >= x);
  }

  function sub(uint256 x, uint256 y) constant internal returns (uint256 z) {
    assert((z = x - y) <= x);
  }

  function mul(uint256 x, uint256 y) constant internal returns (uint256 z) {
    z = x * y;
    assert(x == 0 || z / x == y);
  }

  // div isn't needed. Only error case is div by zero and Solidity throws on that
  // function div(uint256 x, uint256 y) constant internal returns (uint256 z) {
  //   z = x / y;
  // }

  // subMaxZero(x, y)
  // Pacio addition to avoid throwing if a subtraction goes below zero and return 0 in that case.
  function subMaxZero(uint256 x, uint256 y) constant internal returns (uint256 z) {
    if (y > x)
      z = 0;
    else
      z = x - y;
  }
}
