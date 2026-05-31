import 'package:esl_learning_flutter/models/app_models.dart';
import 'package:esl_learning_flutter/theme/app_theme.dart';

const categories = [
  Category(
    id: 'greetings',
    title: 'Greetings',
    titleAm: 'መልካም ሰላምታ',
    icon: '👋',
    color: kPrimary,
    description: 'Learn basic greetings in Ethiopian Sign Language',
  ),
  Category(
    id: 'family',
    title: 'Family',
    titleAm: 'ቤተሰብ',
    icon: '👨‍👩‍👧‍👦',
    color: kDanger,
    description: 'Family members and relationships',
  ),
  Category(
    id: 'food',
    title: 'Food',
    titleAm: 'ምግብ',
    icon: '🍽️',
    color: kAccent,
    description: 'Ethiopian foods and dining',
  ),
  Category(
    id: 'shopping',
    title: 'Shopping',
    titleAm: 'ገበያ',
    icon: '🛒',
    color: kPrimary,
    description: 'Market and shopping vocabulary',
  ),
  Category(
    id: 'emergency',
    title: 'Emergency',
    titleAm: 'አደጋ ጊዜ',
    icon: '🚨',
    color: kDanger,
    description: 'Important emergency signs',
  ),
  Category(
    id: 'numbers',
    title: 'Numbers',
    titleAm: 'ቁጥሮች',
    icon: '🔢',
    color: kAccent,
    description: 'Count from 1 to 100',
  ),
];

const lessonsByCategory = {
  'greetings': [
    LessonItem(
      id: 'g1',
      categoryId: 'greetings',
      sign: 'Hello',
      signAm: 'ሰላም',
      thumbnail: '👋',
      videoUrl: 'drive:1wQoueUDZVv_HBqmmcOmSIST3GqPtW9td',
    ),
    LessonItem(
      id: 'g2',
      categoryId: 'greetings',
      sign: 'Good morning',
      signAm: 'እንደምን አደሩ',
      thumbnail: '🌅',
      videoUrl: 'drive:1wQoueUDZVv_HBqmmcOmSIST3GqPtW9td',
    ),
    LessonItem(
      id: 'g3',
      categoryId: 'greetings',
      sign: 'Good evening',
      signAm: 'እንደምን አመሹ',
      thumbnail: '🌆',
    ),
    LessonItem(
      id: 'g4',
      categoryId: 'greetings',
      sign: 'How are you?',
      signAm: 'እንዴት ነህ?',
      thumbnail: '❓',
    ),
    LessonItem(
      id: 'g5',
      categoryId: 'greetings',
      sign: 'I am fine',
      signAm: 'ደህና ነኝ',
      thumbnail: '😊',
    ),
    LessonItem(
      id: 'g6',
      categoryId: 'greetings',
      sign: 'Thank you',
      signAm: 'አመሰግናለሁ',
      thumbnail: '🙏',
    ),
    LessonItem(
      id: 'g7',
      categoryId: 'greetings',
      sign: 'You are welcome',
      signAm: 'አይገባም',
      thumbnail: '🙂',
    ),
    LessonItem(
      id: 'g8',
      categoryId: 'greetings',
      sign: 'Goodbye',
      signAm: 'ደህና ሁን',
      thumbnail: '👋',
    ),
  ],
  'family': [
    LessonItem(
      id: 'f1',
      categoryId: 'family',
      sign: 'Mother',
      signAm: 'እናት',
      thumbnail: '👩',
    ),
    LessonItem(
      id: 'f2',
      categoryId: 'family',
      sign: 'Father',
      signAm: 'አባት',
      thumbnail: '👨',
    ),
    LessonItem(
      id: 'f3',
      categoryId: 'family',
      sign: 'Sister',
      signAm: 'እህት',
      thumbnail: '👧',
    ),
    LessonItem(
      id: 'f4',
      categoryId: 'family',
      sign: 'Brother',
      signAm: 'ወንድም',
      thumbnail: '👦',
    ),
    LessonItem(
      id: 'f5',
      categoryId: 'family',
      sign: 'Grandmother',
      signAm: 'አያት',
      thumbnail: '👵',
    ),
    LessonItem(
      id: 'f6',
      categoryId: 'family',
      sign: 'Grandfather',
      signAm: 'አያት',
      thumbnail: '👴',
    ),
    LessonItem(
      id: 'f7',
      categoryId: 'family',
      sign: 'Child',
      signAm: 'ልጅ',
      thumbnail: '👶',
    ),
    LessonItem(
      id: 'f8',
      categoryId: 'family',
      sign: 'Family',
      signAm: 'ቤተሰብ',
      thumbnail: '👨‍👩‍👧‍👦',
    ),
    LessonItem(
      id: 'f9',
      categoryId: 'family',
      sign: 'Friend',
      signAm: 'ጓደኛ',
      thumbnail: '👫',
    ),
    LessonItem(
      id: 'f10',
      categoryId: 'family',
      sign: 'Love',
      signAm: 'ፍቅር',
      thumbnail: '❤️',
    ),
  ],
  'food': [
    LessonItem(
      id: 'fd1',
      categoryId: 'food',
      sign: 'Injera',
      signAm: 'እንጀራ',
      thumbnail: '🫓',
    ),
    LessonItem(
      id: 'fd2',
      categoryId: 'food',
      sign: 'Coffee',
      signAm: 'ቡና',
      thumbnail: '☕',
    ),
    LessonItem(
      id: 'fd3',
      categoryId: 'food',
      sign: 'Water',
      signAm: 'ውሃ',
      thumbnail: '💧',
    ),
    LessonItem(
      id: 'fd4',
      categoryId: 'food',
      sign: 'Bread',
      signAm: 'ዳቦ',
      thumbnail: '🍞',
    ),
    LessonItem(
      id: 'fd5',
      categoryId: 'food',
      sign: 'Milk',
      signAm: 'ወተት',
      thumbnail: '🥛',
    ),
    LessonItem(
      id: 'fd6',
      categoryId: 'food',
      sign: 'Eat',
      signAm: 'ብላ',
      thumbnail: '🍴',
    ),
    LessonItem(
      id: 'fd7',
      categoryId: 'food',
      sign: 'Drink',
      signAm: 'ጠጣ',
      thumbnail: '🥤',
    ),
    LessonItem(
      id: 'fd8',
      categoryId: 'food',
      sign: 'Hungry',
      signAm: 'ራብኝ',
      thumbnail: '😋',
    ),
    LessonItem(
      id: 'fd9',
      categoryId: 'food',
      sign: 'Doro Wat',
      signAm: 'ዶሮ ወጥ',
      thumbnail: '🍲',
    ),
    LessonItem(
      id: 'fd10',
      categoryId: 'food',
      sign: 'Teff',
      signAm: 'ጤፍ',
      thumbnail: '🌾',
    ),
    LessonItem(
      id: 'fd11',
      categoryId: 'food',
      sign: 'Kitfo',
      signAm: 'ክትፎ',
      thumbnail: '🥩',
    ),
    LessonItem(
      id: 'fd12',
      categoryId: 'food',
      sign: 'Tea',
      signAm: 'ሻይ',
      thumbnail: '🍵',
    ),
  ],
  'shopping': [
    LessonItem(
      id: 's1',
      categoryId: 'shopping',
      sign: 'Market',
      signAm: 'ገበያ',
      thumbnail: '🏪',
    ),
    LessonItem(
      id: 's2',
      categoryId: 'shopping',
      sign: 'Money',
      signAm: 'ገንዘብ',
      thumbnail: '💰',
    ),
    LessonItem(
      id: 's3',
      categoryId: 'shopping',
      sign: 'Buy',
      signAm: 'ገዛ',
      thumbnail: '🛍️',
    ),
    LessonItem(
      id: 's4',
      categoryId: 'shopping',
      sign: 'Sell',
      signAm: 'ሽጥ',
      thumbnail: '💵',
    ),
    LessonItem(
      id: 's5',
      categoryId: 'shopping',
      sign: 'Price',
      signAm: 'ዋጋ',
      thumbnail: '🏷️',
    ),
    LessonItem(
      id: 's6',
      categoryId: 'shopping',
      sign: 'Expensive',
      signAm: 'ውድ',
      thumbnail: '💸',
    ),
    LessonItem(
      id: 's7',
      categoryId: 'shopping',
      sign: 'Cheap',
      signAm: 'ርካሽ',
      thumbnail: '💲',
    ),
    LessonItem(
      id: 's8',
      categoryId: 'shopping',
      sign: 'Clothes',
      signAm: 'ልብስ',
      thumbnail: '👔',
    ),
    LessonItem(
      id: 's9',
      categoryId: 'shopping',
      sign: 'Shoes',
      signAm: 'ጫማ',
      thumbnail: '👞',
    ),
  ],
  'emergency': [
    LessonItem(
      id: 'e1',
      categoryId: 'emergency',
      sign: 'Help',
      signAm: 'እርዳታ',
      thumbnail: '🆘',
    ),
    LessonItem(
      id: 'e2',
      categoryId: 'emergency',
      sign: 'Hospital',
      signAm: 'ሆስፒታል',
      thumbnail: '🏥',
    ),
    LessonItem(
      id: 'e3',
      categoryId: 'emergency',
      sign: 'Doctor',
      signAm: 'ዶክተር',
      thumbnail: '👨‍⚕️',
    ),
    LessonItem(
      id: 'e4',
      categoryId: 'emergency',
      sign: 'Police',
      signAm: 'ፖሊስ',
      thumbnail: '👮',
    ),
    LessonItem(
      id: 'e5',
      categoryId: 'emergency',
      sign: 'Danger',
      signAm: 'አደጋ',
      thumbnail: '⚠️',
    ),
    LessonItem(
      id: 'e6',
      categoryId: 'emergency',
      sign: 'Emergency',
      signAm: 'አስቸኳይ',
      thumbnail: '🚨',
    ),
  ],
  'numbers': [
    LessonItem(
      id: 'n1',
      categoryId: 'numbers',
      sign: 'One',
      signAm: 'አንድ',
      thumbnail: '1️⃣',
    ),
    LessonItem(
      id: 'n2',
      categoryId: 'numbers',
      sign: 'Two',
      signAm: 'ሁለት',
      thumbnail: '2️⃣',
    ),
    LessonItem(
      id: 'n3',
      categoryId: 'numbers',
      sign: 'Three',
      signAm: 'ሶስት',
      thumbnail: '3️⃣',
    ),
    LessonItem(
      id: 'n4',
      categoryId: 'numbers',
      sign: 'Numbers 1-10',
      signAm: 'ቁጥሮች 1-10',
      thumbnail: '🔟',
    ),
    LessonItem(
      id: 'n5',
      categoryId: 'numbers',
      sign: 'Numbers 11-100',
      signAm: 'ቁጥሮች 11-100',
      thumbnail: '💯',
    ),
  ],
};

/// Total lesson items across all categories in [lessonsByCategory].
int totalCurriculumLessons() =>
    lessonsByCategory.values.fold<int>(0, (sum, list) => sum + list.length);

/// How many [completedLessonIds] appear in the curriculum lists.
int countCompletedInCurriculum(Set<String> completedLessonIds) {
  var n = 0;
  for (final list in lessonsByCategory.values) {
    for (final lesson in list) {
      if (completedLessonIds.contains(lesson.id)) n++;
    }
  }
  return n;
}

/// Completed lessons in [completedLessonIds] that belong to [categoryId].
int countCompletedInCategory(String categoryId, Set<String> completedLessonIds) {
  final list = lessonsByCategory[categoryId];
  if (list == null) return 0;
  var n = 0;
  for (final lesson in list) {
    if (completedLessonIds.contains(lesson.id)) n++;
  }
  return n;
}

/// Overall curriculum completion in the range 0.0–1.0.
double curriculumProgressFraction(Set<String> completedLessonIds) {
  final total = totalCurriculumLessons();
  if (total == 0) return 0;
  return (countCompletedInCurriculum(completedLessonIds) / total).clamp(
    0.0,
    1.0,
  );
}

/// First lesson in category order that is not in [completedLessonIds], or null if all done.
LessonItem? firstIncompleteLesson(Set<String> completedLessonIds) {
  for (final cat in categories) {
    final list = lessonsByCategory[cat.id] ?? const <LessonItem>[];
    for (final lesson in list) {
      if (!completedLessonIds.contains(lesson.id)) return lesson;
    }
  }
  return null;
}

Category categoryForLesson(LessonItem lesson) =>
    categories.firstWhere((c) => c.id == lesson.categoryId);

String continueLessonChipLabel(String language, LessonItem lesson) {
  final cat = categoryForLesson(lesson);
  final list = lessonsByCategory[lesson.categoryId] ?? const <LessonItem>[];
  final idx = list.indexWhere((l) => l.id == lesson.id);
  final n = idx < 0 ? 1 : idx + 1;
  final title = language == 'en' ? cat.title : cat.titleAm;
  return 'Lesson $n: $title';
}

const quizByCategory = {
  'greetings': [
    QuizQuestion(
      type: QuizType.watchAndChoose,
      question: 'Watch the sign and choose the correct meaning',
      questionAm: 'ምልክቱን ተመልከቱ እና ትክክለኛውን ትርጉም ይምረጡ',
      correctAnswer: 'Hello / ሰላም',
      options: [
        'Hello / ሰላም',
        'Goodbye / ደህና ሁን',
        'Thank you / አመሰግናለሁ',
        'Sorry / ይቅርታ',
      ],
    ),
    QuizQuestion(
      type: QuizType.watchAndChoose,
      question: 'Watch the sign and choose the correct meaning',
      questionAm: 'ምልክቱን ተመልከቱ እና ትክክለኛውን ትርጉም ይምረጡ',
      correctAnswer: 'Thank you / አመሰግናለሁ',
      options: [
        'Hello / ሰላም',
        'Thank you / አመሰግናለሁ',
        'I am fine / ደህና ነኝ',
        'Please / እባክህ',
      ],
    ),
    QuizQuestion(
      type: QuizType.watchAndChoose,
      question: 'Choose the correct sign for: How are you?',
      questionAm: 'ለ እንዴት ነህ? ትክክለኛውን ምልክት ይምረጡ',
      correctAnswer: 'How are you? / እንዴት ነህ?',
      options: [
        'How are you? / እንዴት ነህ?',
        'Hello / ሰላም',
        'Goodbye / ደህና ሁን',
        'Thank you / አመሰግናለሁ',
      ],
    ),
  ],
  'family': [
    QuizQuestion(
      type: QuizType.watchAndChoose,
      question: 'Watch the sign and choose the correct meaning',
      questionAm: 'ምልክቱን ተመልከቱ እና ትክክለኛውን ትርጉም ይምረጡ',
      correctAnswer: 'Mother / እናት',
      options: [
        'Mother / እናት',
        'Father / አባት',
        'Sister / እህት',
        'Brother / ወንድም',
      ],
    ),
    QuizQuestion(
      type: QuizType.watchAndChoose,
      question: 'Watch the sign and choose the correct meaning',
      questionAm: 'ምልክቱን ተመልከቱ እና ትክክለኛውን ትርጉም ይምረጡ',
      correctAnswer: 'Family / ቤተሰብ',
      options: ['Friend / ጓደኛ', 'Family / ቤተሰብ', 'Love / ፍቅር', 'Child / ልጅ'],
    ),
  ],
  'food': [
    QuizQuestion(
      type: QuizType.watchAndChoose,
      question: 'Watch the sign and choose the correct meaning',
      questionAm: 'ምልክቱን ተመልከቱ እና ትክክለኛውን ትርጉም ይምረጡ',
      correctAnswer: 'Injera / እንጀራ',
      options: ['Injera / እንጀራ', 'Bread / ዳቦ', 'Rice / ሩዝ', 'Kitfo / ክትፎ'],
    ),
  ],
  'shopping': [
    QuizQuestion(
      type: QuizType.watchAndChoose,
      question: 'Watch the sign and choose the correct meaning',
      questionAm: 'ምልክቱን ተመልከቱ እና ትክክለኛውን ትርጉም ይምረጡ',
      correctAnswer: 'Market / ገበያ',
      options: [
        'Market / ገበያ',
        'School / ትምህርት ቤት',
        'Hospital / ሆስፒታል',
        'Home / ቤት',
      ],
    ),
  ],
  'emergency': [
    QuizQuestion(
      type: QuizType.watchAndChoose,
      question: 'Watch the sign and choose the correct meaning',
      questionAm: 'ምልክቱን ተመልከቱ እና ትክክለኛውን ትርጉም ይምረጡ',
      correctAnswer: 'Help / እርዳታ',
      options: [
        'Help / እርዳታ',
        'Hospital / ሆስፒታል',
        'Doctor / ዶክተር',
        'Police / ፖሊስ',
      ],
    ),
  ],
  'numbers': [
    QuizQuestion(
      type: QuizType.watchAndChoose,
      question: 'Watch the sign and choose the correct meaning',
      questionAm: 'ምልክቱን ተመልከቱ እና ትክክለኛውን ትርጉም ይምረጡ',
      correctAnswer: 'One / አንድ',
      options: ['One / አንድ', 'Two / ሁለት', 'Three / ሶስት', 'Four / አራት'],
    ),
  ],
};
