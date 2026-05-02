import 'package:flutter/cupertino.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mapbox_tut/models/category_item.dart';

const Map<int, CategoryItem> availableIcons = {
  // ─── FOOD & DINING ─────────────────────────────────────────────────────────
  2: CategoryItem(
    name: 'Dining',
    icon: HugeIcons.strokeRoundedRestaurant01,
    color: Color(0xFF0071E3), // Apple Blue
  ),
  16: CategoryItem(
    name: 'Groceries',
    icon: HugeIcons.strokeRoundedApple01,
    color: Color(0xFF00B3E6), // Transition Teal
  ),
  21: CategoryItem(
    name: 'Fruits',
    icon: HugeIcons.strokeRoundedApple01,
    color: Color(0xFF00CC96), // Energy Green
  ),
  27: CategoryItem(
    name: 'Coffee',
    icon: HugeIcons.strokeRoundedCoffee02,
    color: Color(0xFFC25100), // Commodity Rust
  ),
  29: CategoryItem(
    name: 'Snacks',
    icon: HugeIcons.strokeRoundedPizza01,
    color: Color(0xFF0071E3),
  ),
  28: CategoryItem(
    name: 'Alcohol',
    icon: HugeIcons.strokeRoundedDrink,
    color: Color(0xFFC25100),
  ),

  // ─── TRANSPORT & TRAVEL ────────────────────────────────────────────────────
  6: CategoryItem(
    name: 'Taxi',
    icon: HugeIcons.strokeRoundedCar01,
    color: Color(0xFF00B3E6),
  ),
  34: CategoryItem(
    name: 'Taxi',
    icon: HugeIcons.strokeRoundedTaxi,
    color: Color(0xFF00B3E6),
  ),
  35: CategoryItem(
    name: 'Public Transport',
    icon: HugeIcons.strokeRoundedBus02,
    color: Color(0xFF00CC96),
  ),
  33: CategoryItem(
    name: 'Parking',
    icon: HugeIcons.strokeRoundedParkingAreaCircle,
    color: Color(0xFF747780),
  ),
  9: CategoryItem(
    name: 'Travel',
    icon: HugeIcons.strokeRoundedAirplane01,
    color: Color(0xFF0071E3),
  ),

  // ─── HOUSING & UTILITIES ───────────────────────────────────────────────────
  0: CategoryItem(
    name: 'Home',
    icon: HugeIcons.strokeRoundedHome13,
    color: Color(0xFF0071E3),
  ),
  8: CategoryItem(
    name: 'Bills',
    icon: HugeIcons.strokeRoundedIdea01,
    color: Color(0xFFC25100),
  ),
  24: CategoryItem(
    name: 'Household Utilities',
    icon: HugeIcons.strokeRoundedElectricHome01,
    color: Color(0xFFC25100),
  ),
  32: CategoryItem(
    name:
        'Utilities', //** there is household utilities but with a different icon */
    icon: HugeIcons.strokeRoundedBulb,
    color: Color(0xFFC25100),
  ),
  39: CategoryItem(
    name: 'Internet',
    icon: HugeIcons.strokeRoundedWifi01,
    color: Color(0xFF00B3E6),
  ),
  23: CategoryItem(
    name: 'Phone Bill',
    icon: HugeIcons.strokeRoundedCall,
    color: Color(0xFFC25100),
  ),

  // ─── FINANCE & WORK ────────────────────────────────────────────────────────
  18: CategoryItem(
    name: 'Finance',
    icon: HugeIcons.strokeRoundedWallet01,
    color: Color(0xFF0071E3),
  ),
  25: CategoryItem(
    name: 'Savings',
    icon: HugeIcons.strokeRoundedPiggyBank,
    color: Color(0xFF00CC96),
  ),
  3: CategoryItem(
    name: 'Investments',
    icon: HugeIcons.strokeRoundedBank,
    color: Color(0xFF00CC96),
  ),
  40: CategoryItem(
    name: 'Money',
    icon: HugeIcons.strokeRoundedMoney01,
    color: Color(0xFF00CC96),
  ),
  14: CategoryItem(
    name: 'Work',
    icon: HugeIcons.strokeRoundedBriefcase01,
    color: Color(0xFF0071E3),
  ),
  31: CategoryItem(
    name: 'Labour',
    icon: HugeIcons.strokeRoundedLabor,
    color: Color(0xFFC25100),
  ),

  // ─── SHOPPING & ESSENTIALS ─────────────────────────────────────────────────
  1: CategoryItem(
    name: 'Shopping',
    icon: HugeIcons.strokeRoundedShoppingCart02,
    color: CupertinoColors.systemGreen,
  ),
  20: CategoryItem(
    name: 'Electronics',
    icon: HugeIcons.strokeRoundedComputerPhoneSync,
    color: CupertinoColors.systemGrey,
  ),
  17: CategoryItem(
    name: 'Laundry',
    icon: HugeIcons.strokeRoundedShirt01,
    color: CupertinoColors.systemGrey,
  ),
  41: CategoryItem(
    name: 'Repairs',
    icon: HugeIcons.strokeRoundedWrench01,
    color: CupertinoColors.systemGrey,
  ),

  // ─── HEALTH, FAMILY & PERSONAL CARE ────────────────────────────────────────
  7: CategoryItem(
    name: 'Health',
    icon: HugeIcons.strokeRoundedHospital01,
    color: CupertinoColors.systemRed,
  ),
  13: CategoryItem(
    name: 'Fitness',
    icon: HugeIcons.strokeRoundedDumbbell02,
    color: CupertinoColors.activeBlue,
  ),
  38: CategoryItem(
    name: 'Beauty',
    icon: HugeIcons.strokeRoundedMirror,
    color: CupertinoColors.activeBlue,
  ),
  22: CategoryItem(
    name: 'Child Care',
    icon: HugeIcons.strokeRoundedBaby01,
    color: CupertinoColors.systemPink,
  ),
  4: CategoryItem(
    name: 'Pet',
    icon: HugeIcons.strokeRoundedBird,
    color: CupertinoColors.systemMint,
  ),
  37: CategoryItem(
    name: 'Social',
    icon: HugeIcons.strokeRoundedUserGroup,
    color: CupertinoColors.activeGreen,
  ),

  // ─── ENTERTAINMENT & LIFESTYLE ─────────────────────────────────────────────
  10: CategoryItem(
    name: 'Entertainment',
    icon: HugeIcons.strokeRoundedTicketStar,
    color: CupertinoColors.systemPurple,
  ),
  12: CategoryItem(
    name: 'Music',
    icon: HugeIcons.strokeRoundedMusicNote01,
    color: CupertinoColors.systemPink,
  ),
  19: CategoryItem(
    name: 'Gaming',
    icon: HugeIcons.strokeRoundedGameController01,
    color: CupertinoColors.activeOrange,
  ),
  43: CategoryItem(
    name: 'Hobby',
    icon: HugeIcons.strokeRoundedCamera01,
    color: CupertinoColors.systemCyan,
  ),
  26: CategoryItem(
    name: 'Subscriptions',
    icon: HugeIcons.strokeRoundedCalendar02,
    color: CupertinoColors.systemTeal,
  ),
  30: CategoryItem(
    name: 'Person',
    icon: HugeIcons.strokeRoundedUser,
    color: CupertinoColors.systemPurple,
  ),
  36: CategoryItem(
    name: 'Gift',
    icon: HugeIcons.strokeRoundedGift,
    color: CupertinoColors.systemTeal,
  ),

  // ─── EDUCATION & SERVICES ──────────────────────────────────────────────────
  11: CategoryItem(
    name: 'Education',
    icon: HugeIcons.strokeRoundedMortarboard01,
    color: CupertinoColors.activeOrange,
  ),
  5: CategoryItem(
    name: 'Services',
    icon: HugeIcons.strokeRoundedAiCloud01,
    color: CupertinoColors.label,
  ),
  42: CategoryItem(
    name: 'Vacation',
    icon: HugeIcons.strokeRoundedBeach02,
    color: CupertinoColors.activeGreen,
  ),
};
