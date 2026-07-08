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
      videoUrl: 'drive:18XAAByir3Ox_dvfy0l8FUArHAkkD9ImL',
    ),
    LessonItem(
      id: 'g2',
      categoryId: 'greetings',
      sign: 'Thanks to God',
      signAm: 'ለኢሳ አመሰግናለሁ',
      thumbnail: '🙏',
      videoUrl: 'drive:15npLz50wEzN17RgB1LTxZOFD-trCPc4B',
    ),
    LessonItem(
      id: 'g3',
      categoryId: 'greetings',
      sign: 'Good morning',
      signAm: 'እንደምን አደሩ',
      thumbnail: '🌅',
      videoUrl: 'drive:1ubLVSoMB1Ahr6YDjh-mXJDsTlO7DTemC',
    ),
    LessonItem(
      id: 'g4',
      categoryId: 'greetings',
      sign: 'Good afternoon',
      signAm: 'ጀምብ ይመድ',
      thumbnail: '☀️',
      videoUrl: 'drive:1Jq0FXl_OaMjLKJ2Gsrzg1ztLWjUJsH24',
    ),
    LessonItem(
      id: 'g5',
      categoryId: 'greetings',
      sign: 'Good night',
      signAm: 'በላይ ምሕረት',
      thumbnail: '🌙',
      videoUrl: 'drive:1v66K0-B6y5I1iUTIOh1ZVN1sbGJUN85A',
    ),
    LessonItem(
      id: 'g6',
      categoryId: 'greetings',
      sign: 'Bye',
      signAm: 'ደህና ሁን',
      thumbnail: '👋',
      videoUrl: 'drive:1LEaru7GJo3dzY0JEVSeCQI5hXmvwWGib',
    ),
    LessonItem(
      id: 'g7',
      categoryId: 'greetings',
      sign: 'See you later',
      signAm: 'ላተር ትገናኛለህ',
      thumbnail: '👋',
      videoUrl: 'drive:1LEaru7GJo3dzY0JEVSeCQI5hXmvwWGib',
    ),
    LessonItem(
      id: 'g8',
      categoryId: 'greetings',
      sign: 'How are you?',
      signAm: 'እንዴት ነህ?',
      thumbnail: '❓',
      videoUrl: 'drive:1oVPwtlg94ZuT0VpZzfr42LdWF1QcpSJV',
    ),
    LessonItem(
      id: 'g9',
      categoryId: 'greetings',
      sign: 'Long time',
      signAm: 'ረጅም ጊዜ',
      thumbnail: '⏰',
      videoUrl: 'drive:1fdYfyHAjaJTihiUttW2bV301LbjUulE0',
    ),
    LessonItem(
      id: 'g10',
      categoryId: 'greetings',
      sign: 'Have a good day',
      signAm: 'ጥሩ ቀን አግኙ',
      thumbnail: '☀️',
      videoUrl: 'drive:1KmXwjTh4t0MON11VbPFnDoxHYE6hbpqW',
    ),
    LessonItem(
      id: 'g11',
      categoryId: 'greetings',
      sign: 'Fine',
      signAm: 'ደህና',
      thumbnail: '😊',
      videoUrl: 'drive:1bWb2SqaznfOSTruEG8vniMKFa3p7VzHB',
    ),
    LessonItem(
      id: 'g12',
      categoryId: 'greetings',
      sign: 'Where do you live?',
      signAm: 'የት ትኖራለህ?',
      thumbnail: '🏠',
      videoUrl: 'drive:1NrqpFdFHy_4O9J0U8oFZkwhpc5KPmjlM',
    ),
    LessonItem(
      id: 'g13',
      categoryId: 'greetings',
      sign: 'What do you do (Job)?',
      signAm: 'ምን ስራ ታደርጋለህ?',
      thumbnail: '💼',
      videoUrl: 'drive:136QT2gpqAoTXlaIvrllKi6mdNykOx9yE',
    ),
    LessonItem(
      id: 'g14',
      categoryId: 'greetings',
      sign: 'Where do you go?',
      signAm: 'የት ትሄዳለህ?',
      thumbnail: '🚶',
      videoUrl: 'drive:1nEmujqR38qH-gcGyQt_wqpCt18PANvwD',
    ),
    LessonItem(
      id: 'g15',
      categoryId: 'greetings',
      sign: 'Nice to meet you',
      signAm: 'ሰላም ማወቅ ደስ ብሎኛል',
      thumbnail: '🤝',
      videoUrl: 'drive:1B4-kFV_pBG9E1aJaXHEuGUkjOF8EGubm',
    ),
    LessonItem(
      id: 'g16',
      categoryId: 'greetings',
      sign: 'Welcome',
      signAm: 'አብርሆት ወደጣ',
      thumbnail: '🎉',
      videoUrl: 'drive:1JYmIGOFkydHLT1ZsaWsahI_zsjysYdOP',
    ),
    LessonItem(
      id: 'g17',
      categoryId: 'greetings',
      sign: 'Have a good time',
      signAm: 'ጥሩ ጊዜ አግኙ',
      thumbnail: '⏰',
      videoUrl: 'drive:11BxWkwraxLsh6BmRqEC4ueygy7uQmodi',
    ),
  ],
  'family': [
    LessonItem(
      id: 'f1',
      categoryId: 'family',
      sign: 'Mother',
      signAm: 'እናት',
      thumbnail: '👩',
      videoUrl: 'drive:1sDiPwsldo5bNo6odsbfTCntrQUBDQgk_',
    ),
    LessonItem(
      id: 'f2',
      categoryId: 'family',
      sign: 'Father',
      signAm: 'አባት',
      thumbnail: '👨',
      videoUrl: 'drive:1ESRvlcuhz5iojfVVBGInRXBP46gISdVl',
    ),
    LessonItem(
      id: 'f3',
      categoryId: 'family',
      sign: 'Sister',
      signAm: 'እህት',
      thumbnail: '👩',
      videoUrl: 'drive:19gZH4a-Qdul8qeEM7PRn43l67feBdBIy',
      
    ),
    LessonItem(
      id: 'f4',
      categoryId: 'family',
      sign: 'Brother',
      signAm: 'ወንድም',
      thumbnail: '👨',
      videoUrl: 'drive:1odohUER-VAoSmqXTWG8Iax896CGe7bKq',

    ),
    LessonItem(
      id: 'f5',
      categoryId: 'family',
      sign: 'Grandmother',
      signAm: 'አያት',
      thumbnail: '👵',
      videoUrl: 'drive:17VLFlkb7O1QTtdCNy7Aygb4Cf2VSqd3R',

    ),
    LessonItem(
      id: 'f6',
      categoryId: 'family',
      sign: 'Grandfather',
      signAm: 'ታታ',
      thumbnail: '👴',
      videoUrl: 'drive:1KxpwQKAPD5-EvkO2yZFJzcY6n1wCqpIu',

    ),
    LessonItem(
      id: 'f7',
      categoryId: 'family',
      sign: 'Child',
      signAm: 'ልጅ',
      thumbnail: '👶',
      videoUrl: 'drive:1k3RAQJlrVBIYKXdF4nDGQlmpTVL66cEt',
    ),
  
    LessonItem(
      id: 'f9',
      categoryId: 'family',
      sign: 'Friend',
      signAm: 'ጓደኛ',
      thumbnail: '👫',
      videoUrl: 'drive:1D0YPt4xyQY9VGIvDnghwjoFXLm1f5-rz',

    ),
    LessonItem(
      id: 'f10',
      categoryId: 'family',
      sign: 'Sister',
      signAm: 'እህት',
      thumbnail: '👩',
      videoUrl: 'drive:19gZH4a-Qdul8qeEM7PRn43l67feBdBIy',
    ),
   
    LessonItem(
      id: 'f12',
      categoryId: 'family',
      sign: 'Girl',
      signAm: 'ሴት ልጅ',
      thumbnail: '👧',
     videoUrl: 'drive:1QwK06Vx4FW-Htybahh-BavXO3xSQ8anh',

    ),
    LessonItem(
      id: 'f13',
      categoryId: 'family',
      sign: 'Boy',
      signAm: 'ወንድ ልጅ',
      thumbnail: '👦',
      videoUrl: '1z8IhZzPkgDdzP_cYlhP-_oJmxjUdEuT9',
    ),
    LessonItem(
      id: 'f14',
      categoryId: 'family',
      sign: 'Man',
      signAm: 'ወንድ',
      thumbnail: '👨',
      videoUrl: 'drive:1YGt3s2i-Kl9-ZttX3etg06Foxs7ASe5z',
    ),
    LessonItem(
      id: 'f15',
      categoryId: 'family',
      sign: 'Woman',
      signAm: 'ሴት',
      thumbnail: '👩',
      videoUrl: 'drive:1IYMCl7SHg-U5-9nECewaL2L44ZxRxje5',

    ),
    
    LessonItem(
      id: 'f17',
      categoryId: 'family',
      sign: 'Relative',
      signAm: 'ዝምድና',
      thumbnail: '👨‍👩‍👧',
      videoUrl: 'drive:1HopzvMUcoiqshKNnrc1EyLNsdFTKI0Kh',
    ),
   
    LessonItem(
      id: 'f19',
      categoryId: 'family',
      sign: 'Young',
      signAm: 'ወጣት',
      thumbnail: '🧑',
      videoUrl: 'drive:1zHufBT674uc-Sp8jYZYwP5uJRqLjh_GF',
    ),
  ],
  'food': [
    LessonItem(
      id: 'fd1',
      categoryId: 'food',
      sign: 'Injera',
      signAm: 'እንጀራ',
      thumbnail: '🫓',
      videoUrl: 'drive:1mdymoVgUsoM5gs5mABcer23UGGd70pZ6',
    ),
    LessonItem(
      id: 'fd2',
      categoryId: 'food',
      sign: 'Bread',
      signAm: 'ዳቦ',
      thumbnail: '🍞',
      videoUrl: 'drive:1mPSdFy8GHooXWMa7abGpbmJgAE3YPVaz',
    ),
    LessonItem(
      id: 'fd3',
      categoryId: 'food',
      sign: 'Flat Bread',
      signAm: 'ጥንጋዳ',
      thumbnail: '🥖',
      videoUrl: 'drive:1Lk5RwkDz0VnLXMiFv6zBlizpJZ6mmhjA',
    ),
    LessonItem(
      id: 'fd4',
      categoryId: 'food',
      sign: 'Porridge',
      signAm: 'ጫት',
      thumbnail: '🥣',
      videoUrl: 'drive:1bV_c4WwnacLBn0w0omvFhi-HYNan1yWw',
    ),
    LessonItem(
      id: 'fd5',
      categoryId: 'food',
      sign: 'Ambasha',
      signAm: 'አምባሻ',
      thumbnail: '🥐',
      videoUrl: 'drive:13tAh5P8C9FwVFhZHruBG0tZOVIbiaLdx',
    ),
    LessonItem(
      id: 'fd6',
      categoryId: 'food',
      sign: 'Shiro',
      signAm: 'ሽሮ',
      thumbnail: '🍶',
      videoUrl: 'drive:1vpyCRYUY1D5SK4kamPwNM6wOiCnzVHbY',
    ),
    LessonItem(
      id: 'fd7',
      categoryId: 'food',
      sign: 'Tibs',
      signAm: 'ጥብስ',
      thumbnail: '🍳',
      videoUrl: 'drive:1wm2QCNCbpgB09FeOhwYikciJlNGDpCvc',
    ),
    LessonItem(
      id: 'fd8',
      categoryId: 'food',
      sign: 'Raw Meat',
      signAm: 'ጥሬ ስጋ',
      thumbnail: '🥩',
      videoUrl: 'drive:1Wc5Gk2LodLGZpU-C9RA6UoPyB5TgCHkj',
    ),
    LessonItem(
      id: 'fd9',
      categoryId: 'food',
      sign: 'Salad',
      signAm: 'ሰላጣ',
      thumbnail: '🥗',
      videoUrl: 'drive:1xTiPSYHq1FMdE41DCVPO2HQZ2S1EzwTw',
    ),
    LessonItem(
      id: 'fd10',
      categoryId: 'food',
      sign: 'Cabbage',
      signAm: 'ጎመን',
      thumbnail: '🥬',
      videoUrl: 'drive:18LuMN-2SF6BY7S-WDCdLH9ZqxVmlOkSY',
    ),
    LessonItem(
      id: 'fd11',
      categoryId: 'food',
      sign: 'Quanta',
      signAm: 'ቃንጣ',
      thumbnail: '🫘',
      videoUrl: 'drive:1g13u4iJ71x22aXVH38QPCXsZ3a49kJMy',
    ),
    LessonItem(
      id: 'fd12',
      categoryId: 'food',
      sign: 'Egg',
      signAm: 'እንቁላል',
      thumbnail: '🥚',
      videoUrl: 'drive:18D6XxilQ0prjGHoRaLNOYKg8tX-17tkh',
    ),
    LessonItem(
      id: 'fd13',
      categoryId: 'food',
      sign: 'Fruit',
      signAm: 'ፍራፍሬ',
      thumbnail: '🍎',
      videoUrl: 'drive:19xpGU3O7g4JHa1vD_mxIK0_jckzyL-Ye',
    ),
    LessonItem(
      id: 'fd14',
      categoryId: 'food',
      sign: 'Meat',
      signAm: 'ስጋ',
      thumbnail: '🍖',
      videoUrl: 'drive:1Cr4Qx4AMUAk7iTXEpCNZrA21pnL4mFa_',
    ),
    LessonItem(
      id: 'fd15',
      categoryId: 'food',
      sign: 'Honey',
      signAm: 'ማር',
      thumbnail: '🍯',
      videoUrl: 'drive:1N7_o_yTp8DPZ-WvPCoHOPRWNSD7EhX3x',
    ),
    LessonItem(
      id: 'fd16',
      categoryId: 'food',
      sign: 'Tea',
      signAm: 'ሻይ',
      thumbnail: '🍵',
      videoUrl: 'drive:1Ch2pLmyMSdPH0w4AllfAabeJhL0nrw27',
    ),
    LessonItem(
      id: 'fd17',
      categoryId: 'food',
      sign: 'Coffee',
      signAm: 'ቡና',
      thumbnail: '☕',
      videoUrl: 'drive:1BARTcT_VKTd9X-oByjiTWpvmDgpwl7Eo',
    ),
    LessonItem(
      id: 'fd18',
      categoryId: 'food',
      sign: 'Soda',
      signAm: 'ሶዳ',
      thumbnail: '🥤',
      videoUrl: 'drive:1l3I4A-viML5V_R62iauN-3_bDA4t8KKE',
    ),
    LessonItem(
      id: 'fd19',
      categoryId: 'food',
      sign: 'Juice',
      signAm: 'ጁስ',
      thumbnail: '🧃',
      videoUrl: 'drive:1L80RXEPfUCFB7Z5Kt6BckxK2RGPnS6I5',
    ),
    LessonItem(
      id: 'fd20',
      categoryId: 'food',
      sign: 'Atmit',
      signAm: 'አትሚት',
      thumbnail: '🥘',
      videoUrl: 'drive:1Ot7j7821TxXgbxjiznEVZlSmXwlvDBS7',
    ),
    LessonItem(
      id: 'fd21',
      categoryId: 'food',
      sign: 'Milk',
      signAm: 'ወተት',
      thumbnail: '🥛',
      videoUrl: 'drive:1RCuwqmfz229zQOi8WmRoEbKnulSdLxWI',
    ),
  ],
  'shopping': [
    LessonItem(
      id: 's1',
      categoryId: 'shopping',
      sign: 'Pay',
      signAm: 'ክፈል',
      thumbnail: '💳',
      videoUrl: 'drive:128CthES6X6h550XPLBSfAi3WbV8zu_gr',
    ),
    LessonItem(
      id: 's2',
      categoryId: 'shopping',
      sign: 'Receipt',
      signAm: 'ደረሰኝ',
      thumbnail: '🧾',
      videoUrl: 'drive:11-HLTYGl__zM8M3AoTGQ3ZeFDagqCBH6',
    ),
    LessonItem(
      id: 's3',
      categoryId: 'shopping',
      sign: 'Money',
      signAm: 'ገንዘብ',
      thumbnail: '💰',
      videoUrl: 'drive:1q9ftGtxQiCYxWMnEO35co7NGKl1-kBRS',
    ),
    LessonItem(
      id: 's4',
      categoryId: 'shopping',
      sign: 'Exchange/To change money',
      signAm: 'ገንዘብ መቀየር',
      thumbnail: '💱',
      videoUrl: 'drive:1gcDUO_7FWlyRipjL1fddcx5Wy0xxD81g',
    ),
    LessonItem(
      id: 's5',
      categoryId: 'shopping',
      sign: 'Buy',
      signAm: 'ግዛ',
      thumbnail: '🛍️',
      videoUrl: 'drive:1f7TV5wrs8vY_O_QHYQaMUmW2fWucMheC',
    ),
    LessonItem(
      id: 's6',
      categoryId: 'shopping',
      sign: 'Sale',
      signAm: 'ቅናሽ',
      thumbnail: '🏷️',
      videoUrl: 'drive:1MGJM8vbzwTTWbPMxYziOiMuA1XDd94aq',
    ),
    LessonItem(
      id: 's7',
      categoryId: 'shopping',
      sign: 'Expensive',
      signAm: 'ውድ',
      thumbnail: '💲',
      videoUrl: 'drive:18I8-OQEbciCV_zXLvuAeaEdpVoqtqvEC',
    ),
    LessonItem(
      id: 's8',
      categoryId: 'shopping',
      sign: 'Cheap',
      signAm: 'ርካሽ',
      thumbnail: '💸',
      videoUrl: 'drive:1YuJKk73DG6aICG8DAlxcor3bqien8GQk',
    ),
    LessonItem(
      id: 's9',
      categoryId: 'shopping',
      sign: 'Comfortable',
      signAm: 'ምቹ',
      thumbnail: '🛋️',
      videoUrl: 'drive:1lJEC2yJxIV561yuXaSm7nj61ENuTUVJw',
    ),
    LessonItem(
      id: 's10',
      categoryId: 'shopping',
      sign: 'Fashion',
      signAm: 'ፋሽን',
      thumbnail: '👗',
      videoUrl: 'drive:1Qd4AX9huipvUKY-FE8qgKbne-PpeQpGT',
    ),
    LessonItem(
      id: 's11',
      categoryId: 'shopping',
      sign: 'Small',
      signAm: 'ትንሽ',
      thumbnail: '🤏',
      videoUrl: 'drive:1PHd9GOpJVg3nxqNBh9bbBd9HC4zwYdcg',
    ),
    LessonItem(
      id: 's12',
      categoryId: 'shopping',
      sign: 'Large',
      signAm: 'ትልቅ',
      thumbnail: '🐘',
      videoUrl: 'drive:1O5GEieS2gFQItebxsbEVpJWFIcCVyLXU',
    ),
    LessonItem(
      id: 's13',
      categoryId: 'shopping',
      sign: 'Medium',
      signAm: 'መካከለኛ',
      thumbnail: '📏',
      videoUrl: 'drive:1apP179BOaIae59l41OjoE1J8F3Z2J9-L',
    ),
    LessonItem(
      id: 's14',
      categoryId: 'shopping',
      sign: 'How much',
      signAm: 'በስንት ነው',
      thumbnail: '❓',
      videoUrl: 'drive:1Q-BKnzSPDS3Rjr6ReE8T6PeEpfJbgysY',
    ),
  ],
  'emergency': [
    LessonItem(
      id: 'e1',
      categoryId: 'emergency',
      sign: 'Health',
      signAm: 'ጤና',
      thumbnail: '💚',
      videoUrl: 'drive:17Q_MRRuLzdh6n9YFuPGD9eWuaImPnCXP',
    ),
    LessonItem(
      id: 'e2',
      categoryId: 'emergency',
      sign: 'Sick',
      signAm: 'ታመመ',
      thumbnail: '🤒',
      videoUrl: 'drive:1YD9Tdsr1RQuE5NkJThM80UlR4sxgP3oK',
    ),
    LessonItem(
      id: 'e3',
      categoryId: 'emergency',
      sign: 'Fever',
      signAm: 'ትኩሳት',
      thumbnail: '🌡️',
      videoUrl: 'drive:1lml__3ND44t5oxe0CefNH_K5PpUT3cK8',
    ),
    LessonItem(
      id: 'e4',
      categoryId: 'emergency',
      sign: 'Stomachache',
      signAm: 'ሆዱ ይታለማል',
      thumbnail: '🤕',
      videoUrl: 'drive:1M8grlgui_Mf10rofuhyrmr0Efbzg39YS',
    ),
    LessonItem(
      id: 'e5',
      categoryId: 'emergency',
      sign: 'Bone',
      signAm: 'አጥንት',
      thumbnail: '🦴',
      videoUrl: 'drive:1J3m-2NAvm37OdwOtTJ_WNJdjQSV2zs1u',
    ),
    LessonItem(
      id: 'e6',
      categoryId: 'emergency',
      sign: 'Broken',
      signAm: 'የተሰበረ',
      thumbnail: '💔',
      videoUrl: 'drive:1UA6a5---pb2wJxfz59fyGIHbU1mvZ_LK',
    ),
    LessonItem(
      id: 'e7',
      categoryId: 'emergency',
      sign: 'Itch',
      signAm: 'ሙቅ',
      thumbnail: '🙁',
      videoUrl: 'drive:1dbM39getO6z6MDJMoGzpOQ_0_zaqGhFa',
    ),
    LessonItem(
      id: 'e8',
      categoryId: 'emergency',
      sign: 'Cough',
      signAm: 'ሳል',
      thumbnail: '🤧',
      videoUrl: 'drive:1wrwj1cVEq9sIwu38-PnDM9H1dHQBjuTw',
    ),
    LessonItem(
      id: 'e9',
      categoryId: 'emergency',
      sign: 'Dizzy',
      signAm: '머리 ያወዛል',
      thumbnail: '😵',
      videoUrl: 'drive:1dDrZai3A2_oZZPpLmRIOVKc_40f7vhDo',
    ),
    LessonItem(
      id: 'e10',
      categoryId: 'emergency',
      sign: 'Nurse',
      signAm: 'ሙያዊ ታካሚ ተንከባካቢ',
      thumbnail: '👩‍⚕️',
      videoUrl: 'drive:1yN2kc1rX9tLY_ojDOXrpDnnSO8wlOCIs',
    ),
  ],
  'numbers': [
    LessonItem(
      id: 'n1',
      categoryId: 'numbers',
      sign: 'One',
      signAm: 'አንድ',
      thumbnail: '1️⃣',
      videoUrl: 'drive:1OgRQBAg355YRYvinQ765ZY2AhSc-K54w',
    ),
    LessonItem(
      id: 'n2',
      categoryId: 'numbers',
      sign: 'Two',
      signAm: 'ሁለት',
      thumbnail: '2️⃣',
      videoUrl: 'drive:1Tvc6HXWd8pg4x2WoqrDHDdEeI5roW7Yo',
    ),
    LessonItem(
      id: 'n3',
      categoryId: 'numbers',
      sign: 'Three',
      signAm: 'ሶስት',
      thumbnail: '3️⃣',
      videoUrl: 'drive:1FDPF6428X_nDyKXDIes9Og2vR4bpaciD',
    ),
    LessonItem(
      id: 'n4',
      categoryId: 'numbers',
      sign: 'Four',
      signAm: 'አራት',
      thumbnail: '4️⃣',
      videoUrl: 'drive:1rbEb0-7cyVJNkxE3fOxPNCTr5UjL5-f7',
    ),
    LessonItem(
      id: 'n5',
      categoryId: 'numbers',
      sign: 'Five',
      signAm: 'አምስት',
      thumbnail: '5️⃣',
      videoUrl: 'drive:1tSuKZfW7wCNGVhGFqE-oChKO55_5al-f',
    ),
    LessonItem(
      id: 'n6',
      categoryId: 'numbers',
      sign: 'Six',
      signAm: 'ስድስት',
      thumbnail: '6️⃣',
      videoUrl: 'drive:1t_uXZDQeECGVBUmow5pA_nDhoohwLcbx',
    ),
    LessonItem(
      id: 'n7',
      categoryId: 'numbers',
      sign: 'Seven',
      signAm: 'ሰባት',
      thumbnail: '7️⃣',
      videoUrl: 'drive:1XMOUonx8f-QE1ZVrJY6yhNeqFk4Yyx4x',
    ),
    LessonItem(
      id: 'n8',
      categoryId: 'numbers',
      sign: 'Eight',
      signAm: 'ስምንት',
      thumbnail: '8️⃣',
      videoUrl: 'drive:1JZ_dcgb7u7zoMcvsgyxxqv88cUGZe3Xt',
    ),
    LessonItem(
      id: 'n9',
      categoryId: 'numbers',
      sign: 'Nine',
      signAm: 'ዘጠኝ',
      thumbnail: '9️⃣',
      videoUrl: 'drive:1TWKk-VjAnx_4JVo6MRiXLhtCpU-iB6bd',
    ),
    LessonItem(
      id: 'n10',
      categoryId: 'numbers',
      sign: 'Ten',
      signAm: 'አስር',
      thumbnail: '🔟',
      videoUrl: 'drive:1NxWDh-0kNbqANmDHhMcWn1Nm2QgMgXLr',
    ),
    LessonItem(
      id: 'n11',
      categoryId: 'numbers',
      sign: 'Eleven',
      signAm: 'አስራ አንድ',
      thumbnail: '1️⃣1️⃣',
      videoUrl: 'drive:1WKdjbukkQKG7Lv_x6P-4HoqR9J-zdmW-',
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
