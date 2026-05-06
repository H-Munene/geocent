import 'package:flutter/cupertino.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mapbox_tut/models/category_item.dart';

// const Map<int, CategoryItem> availableIcons = {
//   // ─── FOOD & DINING ────
//   2: CategoryItem(
//     name: 'Dining',
//     icon: HugeIcons.strokeRoundedRestaurant01,
//     color: CupertinoColors.systemOrange,
//   ),
//   16: CategoryItem(
//     name: 'Groceries',
//     icon: HugeIcons.strokeRoundedGrapes,
//     color: CupertinoColors.destructiveRed,
//   ),
//   21: CategoryItem(
//     name: 'Delivery',
//     icon: HugeIcons.strokeRoundedContainerTruck01,
//     color: CupertinoColors.activeGreen,
//   ),
//   27: CategoryItem(
//     name: 'Coffee',
//     icon: HugeIcons.strokeRoundedCoffee02,
//     color: CupertinoColors.systemBrown,
//   ),
//   29: CategoryItem(
//     name: 'Snacks',
//     icon: HugeIcons.strokeRoundedPizza01,
//     color: CupertinoColors.systemYellow,
//   ),
//   28: CategoryItem(
//     name: 'Alcohol',
//     icon: HugeIcons.strokeRoundedDrink,
//     color: CupertinoColors.systemBlue,
//   ),

//   // ─── TRANSPORT & TRAVEL
//   // 6: CategoryItem(
//   //   name: 'Taxi',
//   //   icon: HugeIcons.strokeRoundedCar01,
//   //   color: CupertinoColors.systemBlue,
//   // ),
//   34: CategoryItem(
//     name: 'Taxi',
//     icon: HugeIcons.strokeRoundedTaxi,
//     color: CupertinoColors.activeOrange,
//   ),
//   35: CategoryItem(
//     name: 'Public Transport',
//     icon: HugeIcons.strokeRoundedBus02,
//     color: CupertinoColors.systemTeal,
//   ),
//   33: CategoryItem(
//     name: 'Parking',
//     icon: HugeIcons.strokeRoundedParkingAreaCircle,
//     color: CupertinoColors.systemIndigo,
//   ),
//   9: CategoryItem(
//     name: 'Travel',
//     icon: HugeIcons.strokeRoundedAirplane01,
//     color: CupertinoColors.systemTeal,
//   ),

//   // ─── HOUSING & UTILITIES
//   0: CategoryItem(
//     name: 'Home',
//     icon: HugeIcons.strokeRoundedHome13,
//     color: CupertinoColors.systemIndigo,
//   ),
//   8: CategoryItem(
//     name: 'Bills',
//     icon: HugeIcons.strokeRoundedIdea01,
//     color: CupertinoColors.systemYellow,
//   ),
//   24: CategoryItem(
//     name: 'Household Utilities',
//     icon: HugeIcons.strokeRoundedElectricHome01,
//     color: CupertinoColors.systemIndigo,
//   ),
//   32: CategoryItem(
//     name:
//         'Utilities', //** there is household utilities but with a different icon */
//     icon: HugeIcons.strokeRoundedBulb,
//     color: CupertinoColors.activeBlue,
//   ),
//   39: CategoryItem(
//     name: 'Internet',
//     icon: HugeIcons.strokeRoundedWifi01,
//     color: CupertinoColors.activeGreen,
//   ),
//   23: CategoryItem(
//     name: 'Phone Bill',
//     icon: HugeIcons.strokeRoundedCall,
//     color: Color.fromARGB(255, 54, 234, 132),
//   ),

//   // ─── FINANCE & WORK ───
//   18: CategoryItem(
//     name: 'Finance',
//     icon: HugeIcons.strokeRoundedWallet01,
//     color: CupertinoColors.systemPurple,
//   ),
//   25: CategoryItem(
//     name: 'Savings',
//     icon: HugeIcons.strokeRoundedPiggyBank,
//     color: Color.fromARGB(255, 76, 163, 39),
//   ),
//   3: CategoryItem(
//     name: 'Investments',
//     icon: HugeIcons.strokeRoundedBank,
//     color: CupertinoColors.systemBrown,
//   ),
//   40: CategoryItem(
//     name: 'Money',
//     icon: HugeIcons.strokeRoundedMoneyBag02,
//     color: CupertinoColors.systemYellow,
//   ),
//   14: CategoryItem(
//     name: 'Work',
//     icon: HugeIcons.strokeRoundedBriefcase01,
//     color: CupertinoColors.activeGreen,
//   ),
//   31: CategoryItem(
//     name: 'Labour',
//     icon: HugeIcons.strokeRoundedLabor,
//     color: CupertinoColors.destructiveRed,
//   ),

//   // ─── SHOPPING & ESSENTIALS ─────────────────────────────────────────────────
//   1: CategoryItem(
//     name: 'Shopping',
//     icon: HugeIcons.strokeRoundedShoppingCart02,
//     color: CupertinoColors.systemGreen,
//   ),
//   20: CategoryItem(
//     name: 'Electronics',
//     icon: HugeIcons.strokeRoundedComputerPhoneSync,
//     color: Color.fromARGB(255, 194, 51, 115),
//   ),
//   17: CategoryItem(
//     name: 'Laundry',
//     icon: HugeIcons.strokeRoundedShirt01,
//     color: Color.fromARGB(255, 226, 215, 70),
//   ),
//   41: CategoryItem(
//     name: 'Repairs',
//     icon: HugeIcons.strokeRoundedWrench01,
//     color: Color.fromARGB(255, 131, 254, 160),
//   ),

//   // ─── HEALTH, FAMILY & PERSONAL CARE ────────────────────────────────────────
//   7: CategoryItem(
//     name: 'Health',
//     icon: HugeIcons.strokeRoundedHospital01,
//     color: CupertinoColors.systemRed,
//   ),
//   13: CategoryItem(
//     name: 'Fitness',
//     icon: HugeIcons.strokeRoundedDumbbell02,
//     color: CupertinoColors.activeBlue,
//   ),
//   38: CategoryItem(
//     name: 'Beauty',
//     icon: HugeIcons.strokeRoundedMirror,
//     color: CupertinoColors.activeBlue,
//   ),
//   22: CategoryItem(
//     name: 'Child Care',
//     icon: HugeIcons.strokeRoundedBaby01,
//     color: CupertinoColors.systemPink,
//   ),
//   4: CategoryItem(
//     name: 'Pet',
//     icon: HugeIcons.strokeRoundedBird,
//     color: CupertinoColors.systemMint,
//   ),
//   37: CategoryItem(
//     name: 'Social',
//     icon: HugeIcons.strokeRoundedUserGroup,
//     color: CupertinoColors.activeGreen,
//   ),

//   // ─── ENTERTAINMENT & LIFESTYLE ─────────────────────────────────────────────
//   10: CategoryItem(
//     name: 'Entertainment',
//     icon: HugeIcons.strokeRoundedTicketStar,
//     color: CupertinoColors.systemPurple,
//   ),
//   12: CategoryItem(
//     name: 'Music',
//     icon: HugeIcons.strokeRoundedMusicNote01,
//     color: CupertinoColors.systemPink,
//   ),
//   19: CategoryItem(
//     name: 'Gaming',
//     icon: HugeIcons.strokeRoundedGameController01,
//     color: CupertinoColors.activeOrange,
//   ),
//   43: CategoryItem(
//     name: 'Hobby',
//     icon: HugeIcons.strokeRoundedCamera01,
//     color: CupertinoColors.systemCyan,
//   ),
//   26: CategoryItem(
//     name: 'Subscriptions',
//     icon: HugeIcons.strokeRoundedCalendar02,
//     color: CupertinoColors.systemTeal,
//   ),
//   30: CategoryItem(
//     name: 'Person',
//     icon: HugeIcons.strokeRoundedUser,
//     color: CupertinoColors.systemPurple,
//   ),
//   36: CategoryItem(
//     name: 'Gift',
//     icon: HugeIcons.strokeRoundedGift,
//     color: CupertinoColors.systemTeal,
//   ),

//   // ─── EDUCATION & SERVICES ──────────────────────────────────────────────────
//   11: CategoryItem(
//     name: 'Education',
//     icon: HugeIcons.strokeRoundedMortarboard01,
//     color: CupertinoColors.activeOrange,
//   ),
//   5: CategoryItem(
//     name: 'Services',
//     icon: HugeIcons.strokeRoundedAiCloud01,
//     color: CupertinoColors.label,
//   ),
//   42: CategoryItem(
//     name: 'Vacation',
//     icon: HugeIcons.strokeRoundedBeach02,
//     color: CupertinoColors.activeGreen,
//   ),
// };

const Map<int, CategoryItem> availableIcons = {
  // ─── FOOD & DINING ────────────────────────────────────────────────────────
  2: CategoryItem(
    name: 'Dining',
    icon: HugeIcons.strokeRoundedRestaurant01,
    color: CupertinoColors.systemOrange, // #FF9500
  ),
  16: CategoryItem(
    name: 'Groceries',
    icon: HugeIcons.strokeRoundedGrapes,
    color: CupertinoColors.destructiveRed, // #FF3B30
  ),
  21: CategoryItem(
    name: 'Delivery',
    icon: HugeIcons.strokeRoundedContainerTruck01,
    color: CupertinoColors.activeGreen, // #4CD964
  ),
  27: CategoryItem(
    name: 'Coffee',
    icon: HugeIcons.strokeRoundedCoffee02,
    color: CupertinoColors.systemBrown, // #A2845E
  ),
  29: CategoryItem(
    name: 'Snacks',
    icon: HugeIcons.strokeRoundedPizza01,
    color: CupertinoColors.systemYellow, // #FFCC00
  ),
  28: CategoryItem(
    name: 'Alcohol',
    icon: HugeIcons.strokeRoundedDrink,
    color: Color(0xFF5AC8FA), // sky blue
  ),

  // ─── TRANSPORT & TRAVEL ───────────────────────────────────────────────────
  34: CategoryItem(
    name: 'Taxi',
    icon: HugeIcons.strokeRoundedTaxi,
    color: CupertinoColors.activeOrange, // #FF6B00
  ),
  35: CategoryItem(
    name: 'Public Transport',
    icon: HugeIcons.strokeRoundedBus02,
    color: CupertinoColors.systemTeal, // #5AC8C8
  ),
  33: CategoryItem(
    name: 'Parking',
    icon: HugeIcons.strokeRoundedParkingAreaCircle,
    color: CupertinoColors.systemIndigo, // #5856D6
  ),
  9: CategoryItem(
    name: 'Travel',
    icon: HugeIcons.strokeRoundedAirplane01,
    color: Color(0xFF00C7BE), // mint-cyan
  ),

  // ─── HOUSING & UTILITIES ──────────────────────────────────────────────────
  0: CategoryItem(
    name: 'Home',
    icon: HugeIcons.strokeRoundedHome13,
    color: Color(0xFF6E4AE6), // violet
  ),
  8: CategoryItem(
    name: 'Bills',
    icon: HugeIcons.strokeRoundedIdea01,
    color: Color(0xFFFFD60A), // gold-amber
  ),
  24: CategoryItem(
    name: 'Household Utilities',
    icon: HugeIcons.strokeRoundedElectricHome01,
    color: Color(0xFF0A84FF), // iOS system blue
  ),
  32: CategoryItem(
    name: 'Utilities',
    icon: HugeIcons.strokeRoundedBulb,
    color: CupertinoColors.activeBlue, // #007AFF
  ),
  39: CategoryItem(
    name: 'Internet',
    icon: HugeIcons.strokeRoundedWifi01,
    color: Color(0xFF34C759), // system green
  ),
  23: CategoryItem(
    name: 'Phone Bill',
    icon: HugeIcons.strokeRoundedCall,
    color: Color(0xFF36EA84), // bright lime green
  ),

  // ─── FINANCE & WORK ───────────────────────────────────────────────────────
  18: CategoryItem(
    name: 'Finance',
    icon: HugeIcons.strokeRoundedWallet01,
    color: CupertinoColors.systemPurple, // #AF52DE
  ),
  25: CategoryItem(
    name: 'Savings',
    icon: HugeIcons.strokeRoundedPiggyBank,
    color: Color(0xFF4CAF50), // material green
  ),
  3: CategoryItem(
    name: 'Investments',
    icon: HugeIcons.strokeRoundedBank,
    color: Color(0xFF8B5E3C), // dark sienna (distinct from systemBrown)
  ),
  40: CategoryItem(
    name: 'Money',
    icon: HugeIcons.strokeRoundedMoneyBag02,
    color: Color(0xFFFFB300), // deep gold (distinct from yellow/amber)
  ),
  14: CategoryItem(
    name: 'Work',
    icon: HugeIcons.strokeRoundedBriefcase01,
    color: Color(0xFF1C7ED6), // cobalt blue
  ),
  31: CategoryItem(
    name: 'Labour',
    icon: HugeIcons.strokeRoundedLabor,
    color: Color(0xFFE63946), // crimson (distinct from destructiveRed)
  ),

  // ─── SHOPPING & ESSENTIALS ────────────────────────────────────────────────
  1: CategoryItem(
    name: 'Shopping',
    icon: HugeIcons.strokeRoundedShoppingCart02,
    color: CupertinoColors.systemGreen, // #28CD41
  ),
  20: CategoryItem(
    name: 'Electronics',
    icon: HugeIcons.strokeRoundedComputerPhoneSync,
    color: Color(0xFFC2336E), // magenta-rose
  ),
  17: CategoryItem(
    name: 'Laundry',
    icon: HugeIcons.strokeRoundedShirt01,
    color: Color(0xFFE2D746), // lime yellow
  ),
  41: CategoryItem(
    name: 'Repairs',
    icon: HugeIcons.strokeRoundedWrench01,
    color: Color(0xFF83FEA0), // pale mint
  ),

  // ─── HEALTH, FAMILY & PERSONAL CARE ──────────────────────────────────────
  7: CategoryItem(
    name: 'Health',
    icon: HugeIcons.strokeRoundedHospital01,
    color: CupertinoColors.systemRed, // #FF3B30
  ),
  13: CategoryItem(
    name: 'Fitness',
    icon: HugeIcons.strokeRoundedDumbbell02,
    color: Color(0xFF1C86EE), // dodger blue
  ),
  38: CategoryItem(
    name: 'Beauty',
    icon: HugeIcons.strokeRoundedMirror,
    color: CupertinoColors.systemPink, // #FF2D55
  ),
  22: CategoryItem(
    name: 'Child Care',
    icon: HugeIcons.strokeRoundedBaby01,
    color: Color(0xFFFF6EB4), // bubblegum pink
  ),
  4: CategoryItem(
    name: 'Pet',
    icon: HugeIcons.strokeRoundedBird,
    color: CupertinoColors.systemMint, // #00C7BE
  ),
  37: CategoryItem(
    name: 'Social',
    icon: HugeIcons.strokeRoundedUserGroup,
    color: Color(0xFF00B96B), // emerald green
  ),

  // ─── ENTERTAINMENT & LIFESTYLE ────────────────────────────────────────────
  10: CategoryItem(
    name: 'Entertainment',
    icon: HugeIcons.strokeRoundedTicketStar,
    color: Color(0xFF9B59B6), // amethyst
  ),
  12: CategoryItem(
    name: 'Music',
    icon: HugeIcons.strokeRoundedMusicNote01,
    color: Color(0xFFFF2D55), // rose red
  ),
  19: CategoryItem(
    name: 'Gaming',
    icon: HugeIcons.strokeRoundedGameController01,
    color: Color(0xFFFF9F0A), // warm amber
  ),
  43: CategoryItem(
    name: 'Hobby',
    icon: HugeIcons.strokeRoundedCamera01,
    color: CupertinoColors.systemCyan, // #32ADE6
  ),
  26: CategoryItem(
    name: 'Subscriptions',
    icon: HugeIcons.strokeRoundedCalendar02,
    color: Color(0xFF48D1CC), // medium turquoise
  ),
  30: CategoryItem(
    name: 'Person',
    icon: HugeIcons.strokeRoundedUser,
    color: Color(0xFFAF52DE), // orchid purple
  ),
  36: CategoryItem(
    name: 'Gift',
    icon: HugeIcons.strokeRoundedGift,
    color: Color(0xFFFF3CAC), // neon pink
  ),

  // ─── EDUCATION & SERVICES ─────────────────────────────────────────────────
  11: CategoryItem(
    name: 'Education',
    icon: HugeIcons.strokeRoundedMortarboard01,
    color: Color(0xFFFF6B2B), // tangerine
  ),
  5: CategoryItem(
    name: 'Services',
    icon: HugeIcons.strokeRoundedAiCloud01,
    color: Color(0xFF0EAFE2), // electric blue
  ),
  42: CategoryItem(
    name: 'Vacation',
    icon: HugeIcons.strokeRoundedBeach02,
    color: Color(0xFF27C4A2), // seafoam
  ),
};
