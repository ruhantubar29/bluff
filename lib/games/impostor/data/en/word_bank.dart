class WordEntry {
  const WordEntry({
    required this.word,
    required this.hints,
  });

  final String word;
  final List<String> hints;
}

class WordBank {
  WordBank._();

  static const Map<String, List<WordEntry>> bank = {
    "Animals": [
      WordEntry(word: "Elephant", hints: ["Big", "Trunk", "Gray", "Safari", "Tusks"]),
      WordEntry(word: "Tiger", hints: ["Jungle", "Stripes", "Predator", "Orange", "Roar"]),
      WordEntry(word: "Lion", hints: ["King", "Mane", "Pride", "Savanna", "Roar"]),
      WordEntry(word: "Giraffe", hints: ["Tall", "Neck", "Spots", "Savanna", "Leaves"]),
      WordEntry(word: "Monkey", hints: ["Tree", "Banana", "Tail", "Climb", "Jungle"]),
      WordEntry(word: "Bear", hints: ["Honey", "Forest", "Fur", "Claws", "Cave"]),
      WordEntry(word: "Deer", hints: ["Forest", "Antlers", "Hooves", "Grass", "Swift"]),
      WordEntry(word: "Zebra", hints: ["Stripes", "Horse", "Black", "Savanna", "Herd"]),
      WordEntry(word: "Crocodile", hints: ["River", "Scales", "Teeth", "Swamp", "Reptile"]),
      WordEntry(word: "Horse", hints: ["Race", "Stable", "Hooves", "Rider", "Gallop"]),
      WordEntry(word: "Dog", hints: ["Pet", "Bark", "Loyal", "Tail", "Leash"]),
      WordEntry(word: "Cat", hints: ["Pet", "Whiskers", "Meow", "Claws", "Purr"]),
      WordEntry(word: "Rabbit", hints: ["Fast", "Carrot", "Ears", "Burrow", "Hops"]),
      WordEntry(word: "Penguin", hints: ["Ice", "Black", "Waddle", "Antarctica", "Colony"]),
      WordEntry(word: "Snake", hints: ["Venom", "Scales", "Slither", "Reptile", "Fangs"]),
    ],

    "Food": [
      WordEntry(word: "Biryani", hints: ["Rice", "Spicy", "Pot", "Meat", "Aromatic"]),
      WordEntry(word: "Pizza", hints: ["Cheese", "Round", "Slice", "Oven", "Topping"]),
      WordEntry(word: "Burger", hints: ["Bun", "Patty", "Cheese", "Fast food", "Sauce"]),
      WordEntry(word: "Ice Cream", hints: ["Cold", "Cone", "Sweet", "Scoop", "Frozen"]),
      WordEntry(word: "Chocolate", hints: ["Sweet", "Cocoa", "Bar", "Brown", "Dessert"]),
      WordEntry(word: "Noodles", hints: ["Chinese", "Long", "Bowl", "Slurp", "Stir-fry"]),
      WordEntry(word: "Cake", hints: ["Birthday", "Sweet", "Frosting", "Slice", "Oven"]),
      WordEntry(word: "Samosa", hints: ["Fried", "Triangle", "Potato", "Spicy", "Snack"]),
      WordEntry(word: "Sandwich", hints: ["Bread", "Lunch", "Filling", "Layers", "Toast"]),
      WordEntry(word: "Coffee", hints: ["Bitter", "Beans", "Morning", "Caffeine", "Cup"]),
      WordEntry(word: "Tea", hints: ["Cup", "Hot", "Leaves", "Milk", "Brew"]),
      WordEntry(word: "Pasta", hints: ["Italy", "Sauce", "Boil", "Wheat", "Fork"]),
    ],

    "Superheroes": [
      WordEntry(word: "Batman", hints: ["Night", "Gotham", "Cape", "Bat", "Detective"]),
      WordEntry(word: "Superman", hints: ["Flying", "Cape", "Krypton", "Hero", "Strength"]),
      WordEntry(word: "Spider-Man", hints: ["Web", "Mask", "Climb", "Queens", "Spider"]),
      WordEntry(word: "Iron Man", hints: ["Armor", "Arc", "Genius", "Suit", "Stark"]),
      WordEntry(word: "Thor", hints: ["Thunder", "Hammer", "God", "Asgard", "Lightning"]),
      WordEntry(word: "Hulk", hints: ["Angry", "Green", "Strong", "Smash", "Banner"]),
      WordEntry(word: "Captain America", hints: ["Shield", "Stars", "Soldier", "America", "Avenger"]),
      WordEntry(word: "Wonder Woman", hints: ["Bracelets", "Amazon", "Lasso", "Princess", "Warrior"]),
      WordEntry(word: "Flash", hints: ["Speed", "Red", "Lightning", "Running", "Fast"]),
      WordEntry(word: "Aquaman", hints: ["Ocean", "Trident", "Atlantis", "King", "Fish"]),
      WordEntry(word: "Black Panther", hints: ["King", "Wakanda", "Vibranium", "Suit", "Claws"]),
      WordEntry(word: "Deadpool", hints: ["Funny", "Mask", "Sword", "Regeneration", "Mercenary"]),
    ],

    "Sports": [
      WordEntry(word: "Football", hints: ["Goal", "Ball", "Team", "Stadium", "Kick"]),
      WordEntry(word: "Cricket", hints: ["Bat", "Wicket", "Runs", "Pitch", "Bowler"]),
      WordEntry(word: "Tennis", hints: ["Racket", "Court", "Net", "Serve", "Ball"]),
      WordEntry(word: "Badminton", hints: ["Shuttle", "Racket", "Net", "Court", "Smash"]),
      WordEntry(word: "Basketball", hints: ["Hoop", "Court", "Dunk", "Orange", "Dribble"]),
      WordEntry(word: "Volleyball", hints: ["Net", "Serve", "Team", "Court", "Spike"]),
      WordEntry(word: "Boxing", hints: ["Gloves", "Ring", "Punch", "Round", "Fight"]),
      WordEntry(word: "Swimming", hints: ["Water", "Pool", "Laps", "Dive", "Stroke"]),
      WordEntry(word: "Golf", hints: ["Hole", "Club", "Green", "Ball", "Course"]),
      WordEntry(word: "Cycling", hints: ["Wheels", "Helmet", "Road", "Pedal", "Bike"]),
    ],

    "Countries": [
      WordEntry(word: "Bangladesh", hints: ["River", "Dhaka", "Green", "Delta", "Bengal"]),
      WordEntry(word: "India", hints: ["Taj Mahal", "Delhi", "Spices", "Cricket", "Peacock"]),
      WordEntry(word: "Japan", hints: ["Sun", "Tokyo", "Sushi", "Island", "Anime"]),
      WordEntry(word: "Brazil", hints: ["Samba", "Football", "Amazon", "Carnival", "Green"]),
      WordEntry(word: "France", hints: ["Tower", "Paris", "Wine", "Fashion", "Europe"]),
      WordEntry(word: "Australia", hints: ["Kangaroo", "Sydney", "Desert", "Island", "Outback"]),
      WordEntry(word: "USA", hints: ["Stars", "America", "Hollywood", "Dollar", "Liberty"]),
      WordEntry(word: "China", hints: ["Great Wall", "Beijing", "Panda", "Dragon", "Red"]),
      WordEntry(word: "Germany", hints: ["Cars", "Berlin", "Europe", "Beer", "Engineering"]),
      WordEntry(word: "Italy", hints: ["Pizza", "Rome", "Pasta", "Colosseum", "Fashion"]),
    ],

    "Jobs": [
      WordEntry(word: "Doctor", hints: ["Hospital", "Medicine", "Patient", "Stethoscope", "Health"]),
      WordEntry(word: "Teacher", hints: ["School", "Students", "Class", "Books", "Lesson"]),
      WordEntry(word: "Police Officer", hints: ["Uniform", "Law", "Badge", "Patrol", "Station"]),
      WordEntry(word: "Farmer", hints: ["Field", "Crops", "Soil", "Tractor", "Harvest"]),
      WordEntry(word: "Chef", hints: ["Kitchen", "Food", "Knife", "Restaurant", "Recipe"]),
      WordEntry(word: "Pilot", hints: ["Cockpit", "Flight", "Airport", "Wings", "Captain"]),
      WordEntry(word: "Driver", hints: ["Steering", "Road", "Car", "License", "Traffic"]),
      WordEntry(word: "Engineer", hints: ["Blueprint", "Design", "Machine", "Building", "Technical"]),
      WordEntry(word: "Photographer", hints: ["Camera", "Photo", "Lens", "Studio", "Flash"]),
      WordEntry(word: "Singer", hints: ["Microphone", "Music", "Voice", "Stage", "Song"]),
    ],

    "Fruits": [
      WordEntry(word: "Mango", hints: ["King", "Sweet", "Summer", "Yellow", "Juicy"]),
      WordEntry(word: "Banana", hints: ["Monkey", "Yellow", "Peel", "Curved", "Potassium"]),
      WordEntry(word: "Apple", hints: ["Red", "Tree", "Crunchy", "Seeds", "Healthy"]),
      WordEntry(word: "Orange", hints: ["Juice", "Citrus", "Round", "Peel", "Vitamin"]),
      WordEntry(word: "Watermelon", hints: ["Summer", "Green", "Seeds", "Juicy", "Large"]),
      WordEntry(word: "Pineapple", hints: ["Spiky", "Tropical", "Crown", "Yellow", "Sweet"]),
      WordEntry(word: "Grape", hints: ["Bunch", "Vine", "Purple", "Small", "Juicy"]),
      WordEntry(word: "Strawberry", hints: ["Red", "Seeds", "Small", "Sweet", "Heart"]),
      WordEntry(word: "Papaya", hints: ["Seeds", "Orange", "Tropical", "Soft", "Tree"]),
      WordEntry(word: "Coconut", hints: ["Water", "Palm", "Shell", "Tropical", "White"]),
    ],

    "Cartoons": [
      WordEntry(word: "Tom and Jerry", hints: ["Chase", "Cat", "Mouse", "House", "Funny"]),
      WordEntry(word: "Doraemon", hints: ["Pocket", "Robot", "Future", "Gadget", "Blue"]),
      WordEntry(word: "Shinchan", hints: ["Naughty", "Family", "Dance", "Kindergarten", "Funny"]),
      WordEntry(word: "Mickey Mouse", hints: ["Ears", "Disney", "Mouse", "Red", "Gloves"]),
      WordEntry(word: "SpongeBob", hints: ["Ocean", "Square", "Pineapple", "Burger", "Yellow"]),
      WordEntry(word: "Scooby-Doo", hints: ["Dog", "Mystery", "Van", "Ghost", "Gang"]),
      WordEntry(word: "Ben 10", hints: ["Watch", "Aliens", "Green", "Hero", "Transformation"]),
      WordEntry(word: "Pokemon", hints: ["Ball", "Trainer", "Battle", "Creatures", "Pikachu"]),
      WordEntry(word: "The Lion King", hints: ["Savanna", "Lion", "Pride", "King", "Africa"]),
      WordEntry(word: "Frozen", hints: ["Ice", "Snow", "Sisters", "Castle", "Winter"]),
    ],

    "Brands": [
      WordEntry(word: "Apple", hints: ["Bitten", "iPhone", "Fruit", "Technology", "California"]),
      WordEntry(word: "Samsung", hints: ["Galaxy", "Korea", "Phone", "Electronics", "Screen"]),
      WordEntry(word: "Sony", hints: ["PlayStation", "Japan", "Camera", "Music", "Electronics"]),
      WordEntry(word: "Nike", hints: ["Swoosh", "Shoes", "Sport", "Athlete", "Running"]),
      WordEntry(word: "Adidas", hints: ["Stripes", "Shoes", "Sport", "Three", "Football"]),
      WordEntry(word: "McDonald's", hints: ["Burger", "Golden", "Fries", "Chicken", "Fast food"]),
      WordEntry(word: "Coca-Cola", hints: ["Red", "Drink", "Bottle", "Fizz", "Cola"]),
      WordEntry(word: "Pepsi", hints: ["Blue", "Drink", "Cola", "Can", "Logo"]),
      WordEntry(word: "Toyota", hints: ["Car", "Japan", "Engine", "Road", "Hybrid"]),
      WordEntry(word: "Google", hints: ["Search", "Internet", "Chrome", "Colorful", "Android"]),
    ],

    "Anime": [
      WordEntry(word: "Naruto", hints: ["Ramen", "Ninja", "Leaf", "Orange", "Hokage"]),
      WordEntry(word: "One Piece", hints: ["Pirates", "Ocean", "Treasure", "Straw Hat", "Crew"]),
      WordEntry(word: "Bleach", hints: ["Soul", "Sword", "Shinigami", "Orange", "Spirit"]),
      WordEntry(word: "Dragon Ball", hints: ["Saiyan", "Dragon", "Power", "Goku", "Orbs"]),
      WordEntry(word: "Death Note", hints: ["Notebook", "Name", "Death", "Shinigami", "Kira"]),
      WordEntry(word: "Demon Slayer", hints: ["Demons", "Sword", "Breathing", "Kimetsu", "Tanjiro"]),
      WordEntry(word: "Jujutsu Kaisen", hints: ["Curse", "Sorcery", "School", "Yuji", "Sukuna"]),
      WordEntry(word: "Attack on Titan", hints: ["Giants", "Walls", "Scouts", "Titans", "Freedom"]),
      WordEntry(word: "One Punch Man", hints: ["Bald", "Hero", "Punch", "Cape", "Strength"]),
      WordEntry(word: "Pokémon", hints: ["Pokeball", "Trainer", "Pikachu", "Battle", "Creature"]),
    ],
  };

  static List<WordEntry> entriesFor(String categoryName) {
    return bank[categoryName] ?? const [];
  }
}