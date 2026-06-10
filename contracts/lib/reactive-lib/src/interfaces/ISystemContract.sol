// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {IPayable} from "./IPayable.sol";
import {ISubscriptionService} from "./ISubscriptionService.sol";

interface ISystemContract is IPayable, ISubscriptionService {
}
