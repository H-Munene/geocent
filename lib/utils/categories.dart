import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mapbox_tut/models/category_item.dart';

const Map<int, CategoryItem> availableIcons = {
  // ─── FOOD & DINING ─────────────────────────────────────────────────────────
  2: CategoryItem(
    name: 'Dining',
    icon: HugeIcons.strokeRoundedRestaurant01,
    color: CupertinoColors.systemOrange,
  ),
  16: CategoryItem(
    name: 'Groceries',
    icon: HugeIcons.strokeRoundedApple01,
    color: CupertinoColors.destructiveRed,
  ),
  21: CategoryItem(
    name: 'Fruits',
    icon: HugeIcons.strokeRoundedApple01,
    color: Colors.lightGreen,
  ),
  27: CategoryItem(
    name: 'Coffee',
    icon: HugeIcons.strokeRoundedCoffee02,
    color: Colors.orangeAccent,
  ),
  29: CategoryItem(
    name: 'Snacks',
    icon: HugeIcons.strokeRoundedPizza01,
    color: Colors.yellowAccent,
  ),
  28: CategoryItem(
    name: 'Alcohol',
    icon: HugeIcons.strokeRoundedDrink,
    color: Colors.lightBlue,
  ),

  // ─── TRANSPORT & TRAVEL ────────────────────────────────────────────────────
  6: CategoryItem(
    name: 'Taxi',
    icon: HugeIcons.strokeRoundedCar01,
    color: CupertinoColors.systemBlue,
  ),
  34: CategoryItem(
    name: 'Taxi',
    icon: HugeIcons.strokeRoundedTaxi,
    color: Colors.deepOrangeAccent,
  ),
  35: CategoryItem(
    name: 'Public Transport',
    icon: HugeIcons.strokeRoundedBus02,
    color: Colors.tealAccent,
  ),
  33: CategoryItem(
    name: 'Parking',
    icon: HugeIcons.strokeRoundedParkingAreaCircle,
    color: Colors.indigoAccent,
  ),
  9: CategoryItem(
    name: 'Travel',
    icon: HugeIcons.strokeRoundedAirplane01,
    color: CupertinoColors.systemTeal,
  ),

  // ─── HOUSING & UTILITIES ───────────────────────────────────────────────────
  0: CategoryItem(
    name: 'Home',
    icon: HugeIcons.strokeRoundedHome13,
    color: CupertinoColors.systemIndigo,
  ),
  8: CategoryItem(
    name: 'Bills',
    icon: HugeIcons.strokeRoundedIdea01,
    color: CupertinoColors.systemYellow,
  ),
  24: CategoryItem(
    name: 'Household Utilities',
    icon: HugeIcons.strokeRoundedElectricHome01,
    color: Colors.indigo,
  ),
  32: CategoryItem(
    name:
        'Utilities', //** there is household utilities but with a different icon */
    icon: HugeIcons.strokeRoundedBulb,
    color: Colors.blueAccent,
  ),
  39: CategoryItem(
    name: 'Internet',
    icon: HugeIcons.strokeRoundedWifi01,
    color: Colors.lightGreenAccent,
  ),
  23: CategoryItem(
    name: 'Phone Bill',
    icon: HugeIcons.strokeRoundedCall,
    color: Colors.amber,
  ),

  // ─── FINANCE & WORK ────────────────────────────────────────────────────────
  18: CategoryItem(
    name: 'Finance',
    icon: HugeIcons.strokeRoundedWallet01,
    color: Colors.deepPurple,
  ),
  25: CategoryItem(
    name: 'Savings',
    icon: HugeIcons.strokeRoundedPiggyBank,
    color: Colors.lime,
  ),
  3: CategoryItem(
    name: 'Investments',
    icon: HugeIcons.strokeRoundedBank,
    color: CupertinoColors.systemBrown,
  ),
  40: CategoryItem(
    name: 'Money',
    icon: HugeIcons.strokeRoundedMoney01,
    color: Colors.amberAccent,
  ),
  14: CategoryItem(
    name: 'Work',
    icon: HugeIcons.strokeRoundedBriefcase01,
    color: CupertinoColors.activeGreen,
  ),
  31: CategoryItem(
    name: 'Labour',
    icon: HugeIcons.strokeRoundedLabor,
    color: Colors.redAccent,
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
    color: Colors.blueGrey,
  ),
  17: CategoryItem(
    name: 'Laundry',
    icon: HugeIcons.strokeRoundedShirt01,
    color: CupertinoColors.systemGrey,
  ),
  41: CategoryItem(
    name: 'Repairs',
    icon: HugeIcons.strokeRoundedWrench01,
    color: Colors.grey,
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
    color: Colors.lightBlueAccent,
  ),
  22: CategoryItem(
    name: 'Child Care',
    icon: HugeIcons.strokeRoundedBaby01,
    color: Colors.pinkAccent,
  ),
  4: CategoryItem(
    name: 'Pet',
    icon: HugeIcons.strokeRoundedBird,
    color: CupertinoColors.systemMint,
  ),
  37: CategoryItem(
    name: 'Social',
    icon: HugeIcons.strokeRoundedUserGroup,
    color: Colors.greenAccent,
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
    color: Colors.deepOrange,
  ),
  43: CategoryItem(
    name: 'Hobby',
    icon: HugeIcons.strokeRoundedCamera01,
    color: CupertinoColors.systemCyan,
  ),
  26: CategoryItem(
    name: 'Subscriptions',
    icon: HugeIcons.strokeRoundedCalendar02,
    color: Colors.cyan,
  ),
  30: CategoryItem(
    name: 'Person',
    icon: HugeIcons.strokeRoundedUser,
    color: Colors.purpleAccent,
  ),
  36: CategoryItem(
    name: 'Gift',
    icon: HugeIcons.strokeRoundedGift,
    color: Colors.cyanAccent,
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
    color: Colors.lightGreenAccent,
  ),
};
