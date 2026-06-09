import 'package:hugeicons/hugeicons.dart';
import 'package:geocent/models/category_item.dart';

const Map<int, CategoryItem> availableIcons = {
  // ─── FOOD & DINING ────────────────────────────────────────────────────────
  2: CategoryItem(name: 'Dining', icon: HugeIcons.strokeRoundedRestaurant01),
  16: CategoryItem(name: 'Groceries', icon: HugeIcons.strokeRoundedGrapes),
  21: CategoryItem(
    name: 'Delivery',
    icon: HugeIcons.strokeRoundedContainerTruck01,
  ),
  27: CategoryItem(name: 'Coffee', icon: HugeIcons.strokeRoundedCoffee02),
  29: CategoryItem(name: 'Snacks', icon: HugeIcons.strokeRoundedPizza01),
  28: CategoryItem(name: 'Alcohol', icon: HugeIcons.strokeRoundedDrink),

  // ─── TRANSPORT & TRAVEL ───────────────────────────────────────────────────
  34: CategoryItem(name: 'Taxi', icon: HugeIcons.strokeRoundedTaxi),
  35: CategoryItem(
    name: 'Public Transport',
    icon: HugeIcons.strokeRoundedBus02,
  ),
  33: CategoryItem(
    name: 'Parking',
    icon: HugeIcons.strokeRoundedParkingAreaCircle,
  ),
  9: CategoryItem(name: 'Travel', icon: HugeIcons.strokeRoundedAirplane01),

  // ─── HOUSING & UTILITIES ──────────────────────────────────────────────────
  0: CategoryItem(name: 'Home', icon: HugeIcons.strokeRoundedHome13),
  8: CategoryItem(name: 'Bills', icon: HugeIcons.strokeRoundedIdea01),
  24: CategoryItem(
    name: 'Household Utilities',
    icon: HugeIcons.strokeRoundedElectricHome01,
  ),
  32: CategoryItem(name: 'Utilities', icon: HugeIcons.strokeRoundedBulb),
  39: CategoryItem(name: 'Internet', icon: HugeIcons.strokeRoundedWifi01),
  23: CategoryItem(name: 'Phone Bill', icon: HugeIcons.strokeRoundedCall),

  // ─── FINANCE & WORK ───────────────────────────────────────────────────────
  18: CategoryItem(name: 'Finance', icon: HugeIcons.strokeRoundedWallet01),
  25: CategoryItem(name: 'Savings', icon: HugeIcons.strokeRoundedPiggyBank),
  3: CategoryItem(name: 'Investments', icon: HugeIcons.strokeRoundedBank),
  40: CategoryItem(name: 'Money', icon: HugeIcons.strokeRoundedMoneyBag02),
  14: CategoryItem(name: 'Work', icon: HugeIcons.strokeRoundedBriefcase01),
  31: CategoryItem(name: 'Labour', icon: HugeIcons.strokeRoundedLabor),

  // ─── SHOPPING & ESSENTIALS ────────────────────────────────────────────────
  1: CategoryItem(
    name: 'Shopping',
    icon: HugeIcons.strokeRoundedShoppingCart02,
  ),
  20: CategoryItem(
    name: 'Electronics',
    icon: HugeIcons.strokeRoundedComputerPhoneSync,
  ),
  17: CategoryItem(name: 'Laundry', icon: HugeIcons.strokeRoundedShirt01),
  41: CategoryItem(name: 'Repairs', icon: HugeIcons.strokeRoundedWrench01),

  // ─── HEALTH, FAMILY & PERSONAL CARE ──────────────────────────────────────
  7: CategoryItem(name: 'Health', icon: HugeIcons.strokeRoundedHospital01),
  13: CategoryItem(name: 'Fitness', icon: HugeIcons.strokeRoundedDumbbell02),
  38: CategoryItem(name: 'Beauty', icon: HugeIcons.strokeRoundedMirror),
  22: CategoryItem(name: 'Child Care', icon: HugeIcons.strokeRoundedBaby01),
  4: CategoryItem(name: 'Pet', icon: HugeIcons.strokeRoundedBird),
  37: CategoryItem(name: 'Social', icon: HugeIcons.strokeRoundedUserGroup),

  // ─── ENTERTAINMENT & LIFESTYLE ────────────────────────────────────────────
  10: CategoryItem(
    name: 'Entertainment',
    icon: HugeIcons.strokeRoundedTicketStar,
  ),
  12: CategoryItem(name: 'Music', icon: HugeIcons.strokeRoundedMusicNote01),
  19: CategoryItem(
    name: 'Gaming',
    icon: HugeIcons.strokeRoundedGameController01,
  ),
  43: CategoryItem(name: 'Hobby', icon: HugeIcons.strokeRoundedCamera01),
  26: CategoryItem(
    name: 'Subscriptions',
    icon: HugeIcons.strokeRoundedCalendar02,
  ),
  30: CategoryItem(name: 'Person', icon: HugeIcons.strokeRoundedUser),
  36: CategoryItem(name: 'Gift', icon: HugeIcons.strokeRoundedGift),

  // ─── EDUCATION & SERVICES ─────────────────────────────────────────────────
  11: CategoryItem(
    name: 'Education',
    icon: HugeIcons.strokeRoundedMortarboard01,
  ),
  5: CategoryItem(name: 'Services', icon: HugeIcons.strokeRoundedAiCloud01),
  42: CategoryItem(name: 'Vacation', icon: HugeIcons.strokeRoundedBeach02),
  44: CategoryItem(
    name: 'Accomodation',
    icon: HugeIcons.strokeRoundedBedDouble,
  ),

  // ─── ADDITIONAL ICONS ─────────────────────────────────────────────────────
  45: CategoryItem(name: 'Car', icon: HugeIcons.strokeRoundedCar01),
  46: CategoryItem(
    name: 'Insurance',
    icon: HugeIcons.strokeRoundedSecurityCheck,
  ),

  47: CategoryItem(name: 'Charity', icon: HugeIcons.strokeRoundedHeartCheck),
  48: CategoryItem(name: 'Books', icon: HugeIcons.strokeRoundedBook02),

  49: CategoryItem(
    name: 'Medicine',
    icon: HugeIcons.strokeRoundedMedicineBottle01,
  ),

  50: CategoryItem(name: 'Sports', icon: HugeIcons.strokeRoundedBasketball01),
  51: CategoryItem(name: 'Rent', icon: HugeIcons.strokeRoundedKey01),
  52: CategoryItem(name: 'Clothing', icon: HugeIcons.strokeRoundedTShirt),
  53: CategoryItem(name: 'Shoes', icon: HugeIcons.strokeRoundedRunningShoes),
  54: CategoryItem(name: 'Jewelry', icon: HugeIcons.strokeRoundedDiamond),
  55: CategoryItem(name: 'Post', icon: HugeIcons.strokeRoundedMail01),
  56: CategoryItem(name: 'Cinema', icon: HugeIcons.strokeRoundedFilm01),
  57: CategoryItem(name: 'Coffee To Go', icon: HugeIcons.strokeRoundedCoffee01),
  58: CategoryItem(name: 'Fast Food', icon: HugeIcons.strokeRoundedHamburger02),
  59: CategoryItem(name: 'Barber', icon: HugeIcons.strokeRoundedScissor01),
  60: CategoryItem(name: 'Hardware', icon: HugeIcons.strokeRoundedTools),
  61: CategoryItem(name: 'Garden', icon: HugeIcons.strokeRoundedTree01),
  62: CategoryItem(name: 'Swimming', icon: HugeIcons.strokeRoundedSwimming),
  63: CategoryItem(name: 'Yoga', icon: HugeIcons.strokeRoundedYoga01),
  64: CategoryItem(name: 'Dental', icon: HugeIcons.strokeRoundedDentalTooth),
  65: CategoryItem(name: 'Vision', icon: HugeIcons.strokeRoundedGlasses),
  66: CategoryItem(
    name: 'Pharmacy',
    icon: HugeIcons.strokeRoundedMedicineBottle01,
  ),
  67: CategoryItem(
    name: 'Credit Card',
    icon: HugeIcons.strokeRoundedCreditCard,
  ),
  68: CategoryItem(name: 'Golf', icon: HugeIcons.strokeRoundedGolfBat),
  69: CategoryItem(name: 'Cycling', icon: HugeIcons.strokeRoundedBicycle),
  70: CategoryItem(name: 'Hiking', icon: HugeIcons.strokeRoundedMountain),
};
