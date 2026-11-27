package app.geocent.domain

/**
 * Every icon a category can use, keyed by the same numeric ids as the Flutter
 * app (lib/utils/categories.dart). [iconName] is the Hugeicons stroke-rounded
 * icon; drawables are added with the screens that show them.
 */
data class CatalogIcon(val key: Int, val defaultName: String, val iconName: String)

data class DefaultCategory(val name: String, val iconKey: Int, val colorArgb: Long)

object CategoryCatalog {

    val icons: List<CatalogIcon> = listOf(
        CatalogIcon(2, "Dining", "restaurant-01"),
        CatalogIcon(16, "Groceries", "grapes"),
        CatalogIcon(21, "Delivery", "container-truck-01"),
        CatalogIcon(27, "Coffee", "coffee-02"),
        CatalogIcon(29, "Snacks", "pizza-01"),
        CatalogIcon(28, "Alcohol", "drink"),
        CatalogIcon(34, "Taxi", "taxi"),
        CatalogIcon(35, "Public Transport", "bus-02"),
        CatalogIcon(33, "Parking", "parking-area-circle"),
        CatalogIcon(9, "Travel", "airplane-01"),
        CatalogIcon(0, "Home", "home-13"),
        CatalogIcon(8, "Bills", "idea-01"),
        CatalogIcon(24, "Household Utilities", "electric-home-01"),
        CatalogIcon(32, "Utilities", "bulb"),
        CatalogIcon(39, "Internet", "wifi-01"),
        CatalogIcon(23, "Phone Bill", "call"),
        CatalogIcon(18, "Finance", "wallet-01"),
        CatalogIcon(25, "Savings", "piggy-bank"),
        CatalogIcon(3, "Investments", "bank"),
        CatalogIcon(40, "Money", "money-bag-02"),
        CatalogIcon(14, "Work", "briefcase-01"),
        CatalogIcon(31, "Labour", "labor"),
        CatalogIcon(1, "Shopping", "shopping-cart-02"),
        CatalogIcon(20, "Electronics", "computer-phone-sync"),
        CatalogIcon(17, "Laundry", "shirt-01"),
        CatalogIcon(41, "Repairs", "wrench-01"),
        CatalogIcon(7, "Health", "hospital-01"),
        CatalogIcon(13, "Fitness", "dumbbell-02"),
        CatalogIcon(38, "Beauty", "mirror"),
        CatalogIcon(22, "Child Care", "baby-01"),
        CatalogIcon(4, "Pet", "bird"),
        CatalogIcon(37, "Social", "user-group"),
        CatalogIcon(10, "Entertainment", "ticket-star"),
        CatalogIcon(12, "Music", "music-note-01"),
        CatalogIcon(19, "Gaming", "game-controller-01"),
        CatalogIcon(43, "Hobby", "camera-01"),
        CatalogIcon(26, "Subscriptions", "calendar-02"),
        CatalogIcon(30, "Person", "user"),
        CatalogIcon(36, "Gift", "gift"),
        CatalogIcon(11, "Education", "mortarboard-01"),
        CatalogIcon(5, "Services", "ai-cloud-01"),
        CatalogIcon(42, "Vacation", "beach-02"),
        CatalogIcon(44, "Accomodation", "bed-double"),
        CatalogIcon(45, "Car", "car-01"),
        CatalogIcon(46, "Insurance", "security-check"),
        CatalogIcon(47, "Charity", "heart-check"),
        CatalogIcon(48, "Books", "book-02"),
        CatalogIcon(49, "Medicine", "medicine-bottle-01"),
        CatalogIcon(50, "Sports", "basketball-01"),
        CatalogIcon(51, "Rent", "key-01"),
        CatalogIcon(52, "Clothing", "t-shirt"),
        CatalogIcon(53, "Shoes", "running-shoes"),
        CatalogIcon(54, "Jewelry", "diamond"),
        CatalogIcon(55, "Post", "mail-01"),
        CatalogIcon(56, "Cinema", "film-01"),
        CatalogIcon(57, "Coffee To Go", "coffee-01"),
        CatalogIcon(58, "Fast Food", "hamburger-02"),
        CatalogIcon(59, "Barber", "scissor-01"),
        CatalogIcon(60, "Hardware", "tools"),
        CatalogIcon(61, "Garden", "tree-01"),
        CatalogIcon(62, "Swimming", "swimming"),
        CatalogIcon(63, "Yoga", "yoga-01"),
        CatalogIcon(64, "Dental", "dental-tooth"),
        CatalogIcon(65, "Vision", "glasses"),
        CatalogIcon(66, "Pharmacy", "medicine-bottle-01"),
        CatalogIcon(67, "Credit Card", "credit-card"),
        CatalogIcon(68, "Golf", "golf-bat"),
        CatalogIcon(69, "Cycling", "bicycle"),
        CatalogIcon(70, "Hiking", "mountain"),
    )

    /** Seeded into the categories table on first launch (same set and colours as Flutter). */
    val defaults: List<DefaultCategory> = listOf(
        DefaultCategory("Dining", 2, 0xFFFF9500),
        DefaultCategory("Snacks", 29, 0xFFFFCC00),
        DefaultCategory("Public Transport", 35, 0xFFA2845E),
        DefaultCategory("Shopping", 1, 0xFF5AC8FA),
        DefaultCategory("Taxi", 34, 0xFF000000),
        DefaultCategory("Social", 37, 0xB7F303D3),
        DefaultCategory("Entertainment", 10, 0x89028B9D),
        DefaultCategory("Laundry", 17, 0xFFE2D746),
        DefaultCategory("Household Utilities", 24, 0xFF0A84FF),
        DefaultCategory("Phone Bill", 23, 0xFF36EA84),
        DefaultCategory("Subscriptions", 26, 0xFFB6435E),
        DefaultCategory("Savings", 25, 0xFFBAC33A),
        DefaultCategory("Health", 7, 0xFFFF3B30),
        DefaultCategory("Services", 5, 0xFF0EAFE2),
        DefaultCategory("Hobby", 43, 0xFF5856D6),
        DefaultCategory("Pet", 4, 0xFF00C7BE),
    )

    /** Colour for a category that has none (Cupertino systemGrey2). */
    const val FALLBACK_COLOR: Long = 0xFFAEAEB2

    fun icon(key: Int): CatalogIcon? = icons.firstOrNull { it.key == key }
}
