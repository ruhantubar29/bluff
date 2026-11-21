/// Every dilemma the game ships with, in both languages side by side.
///
/// Editing rules — this file is meant to be hand-edited:
///
///   * `category` must be one of the ids in `data/categories.dart`:
///     `classic`, `party`, `spicy`, `taboo`, `deep`.
///   * `en` and `bn` are the two sides of the choice, separated by `|`
///     — the same format the original HTML source used, so a question can be
///     pasted straight across. Never let a single option contain a `|`.
///   * Both languages must always hold the same number of questions per
///     category. A missing translation is a bug, not an omission.
///
/// Questions never repeat until the whole selected deck has been dealt.
class WouldYouRatherQuestion {
  const WouldYouRatherQuestion({
    required this.category,
    required this.en,
    required this.bn,
  });

  /// Which category this belongs to — a `WouldYouRatherCategory.id`.
  final String category;

  /// English, as `option A|option B`.
  final String en;

  /// Bangla, as `option A|option B`.
  final String bn;
}

const List<WouldYouRatherQuestion> wouldYouRatherQuestions = [
  // ── CLASSIC ──
  WouldYouRatherQuestion(
    category: 'classic',
    en: 'Be able to fly|Be invisible',
    bn: 'উড়তে পারা|অদৃশ্য হওয়া',
  ),
  WouldYouRatherQuestion(
    category: 'classic',
    en: 'Always be 10 minutes late|Always be 20 minutes early',
    bn: 'সবসময় ১০ মিনিট দেরি|সবসময় ২০ মিনিট আগে',
  ),
  WouldYouRatherQuestion(
    category: 'classic',
    en: 'Live without music|Live without movies',
    bn: 'সংগীত ছাড়া বাঁচা|সিনেমা ছাড়া বাঁচা',
  ),
  WouldYouRatherQuestion(
    category: 'classic',
    en: 'Only eat pizza forever|Never eat pizza again',
    bn: 'চিরদিন শুধু পিজা খাওয়া|আর কখনও পিজা না খাওয়া',
  ),
  WouldYouRatherQuestion(
    category: 'classic',
    en: 'Have a rewind button|Have a pause button',
    bn: 'রিওয়াইন্ড বাটন থাকা|পজ বাটন থাকা',
  ),
  WouldYouRatherQuestion(
    category: 'classic',
    en: 'Talk to animals|Speak every language',
    bn: 'প্রাণীদের সাথে কথা বলা|সব ভাষা বলা',
  ),
  WouldYouRatherQuestion(
    category: 'classic',
    en: 'A month without the internet|A month without seeing friends',
    bn: 'এক মাস ইন্টারনেট ছাড়া|এক মাস বন্ধু দেখা ছাড়া',
  ),
  WouldYouRatherQuestion(
    category: 'classic',
    en: 'Be famous|Be rich and unknown',
    bn: 'ফেমাস হওয়া|ধনী কিন্তু অজানা হওয়া',
  ),
  WouldYouRatherQuestion(
    category: 'classic',
    en: 'Never use a phone again|Never use a computer again',
    bn: 'আর কখনও ফোন না ব্যবহার|আর কখনও কম্পিউটার না ব্যবহার',
  ),
  WouldYouRatherQuestion(
    category: 'classic',
    en: 'Live in the past|Live in the future',
    bn: 'অতীতে বাঁচা|ভবিষ্যতে বাঁচা',
  ),
  WouldYouRatherQuestion(
    category: 'classic',
    en: 'Have unlimited free travel|Have unlimited free food',
    bn: 'যত খুশি ফ্রি ঘোরা|যত খুশি ফ্রি খাওয়া',
  ),
  WouldYouRatherQuestion(
    category: 'classic',
    en: 'Always be too hot|Always be too cold',
    bn: 'সবসময় বেশি গরম|সবসময় বেশি ঠান্ডা',
  ),
  WouldYouRatherQuestion(
    category: 'classic',
    en: 'Win the lottery|Live twice as long',
    bn: 'লটারি জেতা|দ্বিগুণ বেশি দিন বাঁচা',
  ),
  WouldYouRatherQuestion(
    category: 'classic',
    en: 'Have a personal chef|Have a personal driver',
    bn: 'নিজের রাঁধুনি|নিজের চালক',
  ),

  // ── PARTY ──
  WouldYouRatherQuestion(
    category: 'party',
    en: 'Sing karaoke in front of everyone|Dance solo on a table',
    bn: 'সবার সামনে কারাওকি গাওয়া|টেবিলে উঠে একা নাচা',
  ),
  WouldYouRatherQuestion(
    category: 'party',
    en: 'Have your search history shown on a big screen|Have your camera roll shown on a big screen',
    bn: 'সার্চ হিস্ট্রি বড় পর্দায় দেখানো|ক্যামেরা রোল বড় পর্দায় দেখানো',
  ),
  WouldYouRatherQuestion(
    category: 'party',
    en: 'Wear a costume for a whole week|Speak in rhymes for a whole day',
    bn: 'পুরো সপ্তাহ কস্টিউম পরা|পুরো দিন ছন্দে কথা বলা',
  ),
  WouldYouRatherQuestion(
    category: 'party',
    en: 'Eat a spoon of hot sauce|Drink a glass of pickle juice',
    bn: 'এক চামচ হট সস খাওয়া|এক গ্লাস আচারের পানি পান',
  ),
  WouldYouRatherQuestion(
    category: 'party',
    en: 'Text your boss "I love you"|Text your ex "I miss you"',
    bn: 'বসকে মেসেজ "আমি তোমাকে ভালোবাসি"|এক্সকে মেসেজ "তোমাকে মিস করি"',
  ),
  WouldYouRatherQuestion(
    category: 'party',
    en: 'Be the loudest in the room|Be the funniest in the room',
    bn: 'সবার চেয়ে জোরে কথা বলা|সবার চেয়ে বেশি হাসানো',
  ),
  WouldYouRatherQuestion(
    category: 'party',
    en: 'Have a food fight|Have a water balloon fight',
    bn: 'খাবার দিয়ে লড়াই|পানির বেলুন দিয়ে লড়াই',
  ),
  WouldYouRatherQuestion(
    category: 'party',
    en: 'Lose your phone at the party|Lose your shoes at the party',
    bn: 'পার্টিতে ফোন হারানো|পার্টিতে জুতা হারানো',
  ),
  WouldYouRatherQuestion(
    category: 'party',
    en: 'Do a cartwheel in public|Do the worm in public',
    bn: 'পাব্লিকে কার্টহুইল করা|পাব্লিকে ওয়ার্ম ডান্স করা',
  ),
  WouldYouRatherQuestion(
    category: 'party',
    en: 'Only whisper forever|Only shout forever',
    bn: 'চিরদিন ফিসফিস করা|চিরদিন চিৎকার করা',
  ),
  WouldYouRatherQuestion(
    category: 'party',
    en: 'Wear your clothes backwards for a month|Wear pajamas everywhere for a month',
    bn: 'এক মাস কাপড় উল্টো পরা|এক মাস সবখানে পাজামা পরা',
  ),
  WouldYouRatherQuestion(
    category: 'party',
    en: 'Get stuck in an elevator with a stranger|Get stuck in an elevator with a mime',
    bn: 'অচেনা লোকের সাথে লিফটে আটকা পড়া|প্যান্টোমাইমের সাথে লিফটে আটকা পড়া',
  ),

  // ── SPICY ──
  WouldYouRatherQuestion(
    category: 'spicy',
    en: 'Be a great flirt|Be a great kisser',
    bn: 'ফ্লার্টিংয়ে দক্ষ হওয়া|কিসে দক্ষ হওয়া',
  ),
  WouldYouRatherQuestion(
    category: 'spicy',
    en: 'Send a risky text and regret it|Never send it and wonder forever',
    bn: 'ঝুঁকিপূর্ণ মেসেজ পাঠিয়ে অনুতপ্ত হওয়া|না পাঠিয়ে চিরদিন ভাবা',
  ),
  WouldYouRatherQuestion(
    category: 'spicy',
    en: 'Go on a blind date tomorrow|Be set up by your parents',
    bn: 'কাল ব্লাইন্ড ডেটে যাওয়া|বাবা-মার দেওয়া ডেটে যাওয়া',
  ),
  WouldYouRatherQuestion(
    category: 'spicy',
    en: 'A candlelit dinner|A moonlit walk',
    bn: 'মোমবাতির আলোয় ডিনার|চাঁদের আলোয় হাঁটা',
  ),
  WouldYouRatherQuestion(
    category: 'spicy',
    en: 'Be irresistible to everyone|Be unforgettable to one person',
    bn: 'সবার কাছে অপরিহার্য হওয়া|একজনের কাছে অবিস্মরণীয় হওয়া',
  ),
  WouldYouRatherQuestion(
    category: 'spicy',
    en: 'Get a surprise kiss|Give a surprise kiss',
    bn: 'সারপ্রাইজ কিস পাওয়া|সারপ্রাইজ কিস দেওয়া',
  ),
  WouldYouRatherQuestion(
    category: 'spicy',
    en: "Date your best friend's sibling|Date a coworker",
    bn: 'বেস্ট ফ্রেন্ডের ভাই-বোনকে ডেট করা|সহকর্মীকে ডেট করা',
  ),
  WouldYouRatherQuestion(
    category: 'spicy',
    en: 'Have a secret admirer|Be a secret admirer',
    bn: 'গোপন ভালোবাসাদাতা থাকা|নিজে গোপনে ভালোবাসা',
  ),
  WouldYouRatherQuestion(
    category: 'spicy',
    en: "Always know what they're thinking|Always know what they want to hear",
    bn: 'সবসময় তার চিন্তা জানা|সবসময় যা শুনতে চায় তা জানা',
  ),
  WouldYouRatherQuestion(
    category: 'spicy',
    en: 'Slow dance in public|Whisper something sweet in public',
    bn: 'পাব্লিকে স্লো ডান্স করা|পাব্লিকে মিষ্টি কিছু ফিসফিস করা',
  ),
  WouldYouRatherQuestion(
    category: 'spicy',
    en: 'Wake up next to a celebrity|Wake up next to your crush',
    bn: 'সেলিব্রিটির পাশে ঘুম থেকে ওঠা|ক্রাশের পাশে ঘুম থেকে ওঠা',
  ),
  WouldYouRatherQuestion(
    category: 'spicy',
    en: 'Be too bold|Be too shy',
    bn: 'বেশি সাহসী হওয়া|বেশি লাজুক হওয়া',
  ),

  // ── TABOO ──
  WouldYouRatherQuestion(
    category: 'taboo',
    en: 'Everyone reads your old diary|Everyone reads your old messages',
    bn: 'সবাই তোমার পুরনো ডায়েরি পড়ে|সবাই তোমার পুরনো মেসেজ পড়ে',
  ),
  WouldYouRatherQuestion(
    category: 'taboo',
    en: 'Be caught talking to yourself|Be caught singing to yourself',
    bn: 'নিজের সাথে কথা বলতে ধরা পড়া|নিজের সাথে গান গাইতে ধরা পড়া',
  ),
  WouldYouRatherQuestion(
    category: 'taboo',
    en: 'Have your worst cringe moment go viral|Relive it every night in your dreams',
    bn: 'সবচেয়ে ক্রিঞ্জ মুহূর্ত ভাইরাল হওয়া|প্রতি রাতে স্বপ্নে তা ঘটা',
  ),
  WouldYouRatherQuestion(
    category: 'taboo',
    en: 'Admit your guilty pleasure song|Admit your secret crush',
    bn: 'গোপন পছন্দের গান মানতে হওয়া|গোপন ক্রাশ মানতে হওয়া',
  ),
  WouldYouRatherQuestion(
    category: 'taboo',
    en: 'Fake being sick for a week|Fake laughing at a joke for a year',
    bn: 'এক সপ্তাহ অসুস্থ ভান|এক বছর হাসি ভান',
  ),
  WouldYouRatherQuestion(
    category: 'taboo',
    en: 'Have your voicemail played aloud|Have your browser tabs shown aloud',
    bn: 'ভয়েসমেইল সবার সামনে চালানো|ব্রাউজার ট্যাব সবার সামনে দেখানো',
  ),
  WouldYouRatherQuestion(
    category: 'taboo',
    en: 'Trip in front of your crush|Call your teacher "mom" in front of everyone',
    bn: 'ক্রাশের সামনে পড়ে যাওয়া|সবার সামনে শিক্ষককে "মা" বলা',
  ),
  WouldYouRatherQuestion(
    category: 'taboo',
    en: 'Be honest about every opinion|Never share an opinion again',
    bn: 'প্রতিটি মত সৎভাবে বলা|আর কোনো মত না বলা',
  ),
  WouldYouRatherQuestion(
    category: 'taboo',
    en: 'Have everyone know your biggest lie|Have everyone know your biggest fear',
    bn: 'সবাই তোমার বড় মিথ্যা জানুক|সবাই তোমার বড় ভয় জানুক',
  ),
  WouldYouRatherQuestion(
    category: 'taboo',
    en: 'Accidentally like an old photo from years ago|Accidentally send a message to the wrong person',
    bn: 'বছরের পুরনো ছবিতে এক্সিডেন্টালি লাইক|ভুল লোকের কাছে মেসেজ পাঠানো',
  ),
  WouldYouRatherQuestion(
    category: 'taboo',
    en: 'Be known for one embarrassing story|Be forgotten entirely',
    bn: 'একটা লজ্জাজনক গল্প দিয়ে পরিচিত হওয়া|সম্পূর্ণ ভুলে যাওয়া',
  ),
  WouldYouRatherQuestion(
    category: 'taboo',
    en: 'Reply "you too" to a waiter|Wave back at someone not waving at you',
    bn: 'ওয়েটারকে "তুমিও" বলা|যে হাত নাড়ছে না তাকে হাত নাড়া',
  ),

  // ── DEEP ──
  WouldYouRatherQuestion(
    category: 'deep',
    en: 'Know exactly when you will die|Know exactly how you will die',
    bn: 'কবে মরবে তা জানা|কীভাবে মরবে তা জানা',
  ),
  WouldYouRatherQuestion(
    category: 'deep',
    en: 'Be loved by many but known by none|Be known by one but loved by few',
    bn: 'সবার ভালোবাসা কিন্তু কেউ চেনে না|একজন চেনে কিন্তু ভালোবাসে অল্প',
  ),
  WouldYouRatherQuestion(
    category: 'deep',
    en: 'Forget your worst memory|Keep your best memory forever',
    bn: 'সবচেয়ে খারাপ স্মৃতি ভুলে যাওয়া|সেরা স্মৃতি চিরদিন রাখা',
  ),
  WouldYouRatherQuestion(
    category: 'deep',
    en: 'Always hear the hard truth|Always hear a comforting lie',
    bn: 'সবসময় কঠিন সত্য শোনা|সবসময় আরামদায়ক মিথ্যা শোনা',
  ),
  WouldYouRatherQuestion(
    category: 'deep',
    en: 'Relive one day forever|Never be able to look back',
    bn: 'এক দিন বারবার বাঁচা|কখনও পেছনে তাকানো না পারা',
  ),
  WouldYouRatherQuestion(
    category: 'deep',
    en: 'Lose all your ambition|Lose all your fear',
    bn: 'সম্পূর্ণ উৎসাহ হারানো|সম্পূর্ণ ভয় হারানো',
  ),
  WouldYouRatherQuestion(
    category: 'deep',
    en: 'Be remembered for something small|Be forgotten for something big',
    bn: 'ছোট কিছুর জন্য মনে রাখা হওয়া|বড় কিছু হয়েও ভুলে যাওয়া',
  ),
  WouldYouRatherQuestion(
    category: 'deep',
    en: "Read everyone's thoughts for a day|Have everyone read yours for a day",
    bn: 'এক দিন সবার চিন্তা পড়া|এক দিন সবাই তোমার চিন্তা পড়া',
  ),
  WouldYouRatherQuestion(
    category: 'deep',
    en: 'Spend life chasing a dream and fail|Never chase it and always wonder',
    bn: 'স্বপ্ন ধরে ধরে ব্যর্থ হওয়া|না ধরে চিরদিন ভাবা',
  ),
  WouldYouRatherQuestion(
    category: 'deep',
    en: 'Go back and fix one mistake|Go forward and skip one hardship',
    bn: 'পেছনে গিয়ে একটা ভুল ঠিক করা|সামনে গিয়ে একটা কষ্ট এড়ানো',
  ),
  WouldYouRatherQuestion(
    category: 'deep',
    en: 'Have all the answers|Have all the time',
    bn: 'সব উত্তর জানা|সব সময় থাকা',
  ),
  WouldYouRatherQuestion(
    category: 'deep',
    en: 'Be deeply understood by a stranger|Be misunderstood by someone you love',
    bn: 'অচেনা লোকের কাছে গভীরভাবে বোঝা হওয়া|ভালোবারা লোকের কাছে ভুল বোঝা হওয়া',
  ),
];
