/// Lightweight, dependency-free localisation for O'zbek / English / Русский.
enum AppLang { uz, en, ru }

class L10n {
  const L10n(this.lang);
  final AppLang lang;

  String _t(String uz, String en, String ru) => switch (lang) {
        AppLang.uz => uz,
        AppLang.en => en,
        AppLang.ru => ru,
      };

  // ---------- Calendar ----------
  static const _monthsUz = ['Yanvar', 'Fevral', 'Mart', 'Aprel', 'May', 'Iyun', 'Iyul', 'Avgust', 'Sentabr', 'Oktabr', 'Noyabr', 'Dekabr'];
  static const _monthsEn = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
  static const _monthsRu = ['Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь', 'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'];
  static const _monthsRuGen = ['января', 'февраля', 'марта', 'апреля', 'мая', 'июня', 'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'];

  static const _daysUz = ['Dushanba', 'Seshanba', 'Chorshanba', 'Payshanba', 'Juma', 'Shanba', 'Yakshanba'];
  static const _daysEn = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  static const _daysRu = ['Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота', 'Воскресенье'];

  static const _shortUz = ['Du', 'Se', 'Ch', 'Pa', 'Ju', 'Sh', 'Ya'];
  static const _shortEn = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _shortRu = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

  static const _letterUz = ['D', 'S', 'C', 'P', 'J', 'S', 'Y'];
  static const _letterEn = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const _letterRu = ['П', 'В', 'С', 'Ч', 'П', 'С', 'В'];

  String month(int m) => switch (lang) {
        AppLang.uz => _monthsUz[m - 1],
        AppLang.en => _monthsEn[m - 1],
        AppLang.ru => _monthsRu[m - 1],
      };

  String monthShort(int m) {
    final full = month(m);
    if (lang == AppLang.uz && m == 5) return 'May';
    return full.length <= 4 ? full : full.substring(0, 3);
  }

  String weekday(int wd) => switch (lang) {
        AppLang.uz => _daysUz[wd - 1],
        AppLang.en => _daysEn[wd - 1],
        AppLang.ru => _daysRu[wd - 1],
      };

  String weekdayShort(int wd) => switch (lang) {
        AppLang.uz => _shortUz[wd - 1],
        AppLang.en => _shortEn[wd - 1],
        AppLang.ru => _shortRu[wd - 1],
      };

  String weekdayLetter(int wd) => switch (lang) {
        AppLang.uz => _letterUz[wd - 1],
        AppLang.en => _letterEn[wd - 1],
        AppLang.ru => _letterRu[wd - 1],
      };

  /// e.g. "Seshanba, 18-noyabr" / "Tuesday, November 18" / "Вторник, 18 ноября"
  String longDate(DateTime d) => switch (lang) {
        AppLang.uz => '${weekday(d.weekday)}, ${d.day}-${month(d.month).toLowerCase()}',
        AppLang.en => '${weekday(d.weekday)}, ${month(d.month)} ${d.day}',
        AppLang.ru => '${weekday(d.weekday)}, ${d.day} ${_monthsRuGen[d.month - 1]}',
      };

  /// e.g. "Se 18" style compact date
  String compactDate(DateTime d) => '${weekdayShort(d.weekday)} ${d.day}';

  // ---------- Weather ----------
  String weatherText(int code) {
    if (code == 0) return _t('Ochiq osmon', 'Clear', 'Ясно');
    if (code == 1) return _t('Asosan ochiq', 'Mostly Clear', 'Малооблачно');
    if (code == 2) return _t('Qisman bulutli', 'Partly Cloudy', 'Переменная облачность');
    if (code == 3) return _t('Bulutli', 'Mostly Cloudy', 'Пасмурно');
    if (code == 45 || code == 48) return _t('Tuman', 'Fog', 'Туман');
    if (code >= 51 && code <= 57) return _t('Mayda yomg\'ir', 'Drizzle', 'Морось');
    if (code == 65 || code == 67) return _t('Kuchli yomg\'ir', 'Heavy Rain', 'Сильный дождь');
    if (code >= 61 && code <= 67) return _t('Yomg\'ir', 'Rain', 'Дождь');
    if (code >= 71 && code <= 77) return _t('Qor', 'Snow', 'Снег');
    if (code >= 80 && code <= 82) return _t('Jala', 'Showers', 'Ливень');
    if (code == 85 || code == 86) return _t('Qor bo\'roni', 'Snow Showers', 'Снегопад');
    if (code == 95) return _t('Momaqaldiroq', 'Thunderstorm', 'Гроза');
    if (code == 96 || code == 99) return _t('Do\'l', 'Hail', 'Град');
    return _t('Noma\'lum', 'Unknown', 'Неизвестно');
  }

  String get high => _t('Maks', 'H', 'Макс');
  String get low => _t('Min', 'L', 'Мин');
  String get now => _t('Hozir', 'Now', 'Сейчас');
  String get noLocation => _t('Joylashuv yo\'q', 'No location', 'Нет геопозиции');
  String get loadingWeather => _t('Ob-havo yuklanmoqda', 'Loading weather', 'Загрузка погоды');
  String get tapToEnableLocation => _t('Ob-havo uchun joylashuvga ruxsat bering', 'Allow location to see weather', 'Разрешите геопозицию для погоды');
  String get offline => _t('Oflayn', 'Offline', 'Офлайн');

  // ---------- Media ----------
  String get notPlaying => _t('Hech narsa ijro etilmayapti', 'Not Playing', 'Ничего не играет');
  String get notPlayingHint => _t('Musiqa ilovasida qo\'shiq qo\'ying', 'Start music in any app', 'Включите музыку в любом приложении');
  String get mediaAccessTitle => _t('Media ruxsati kerak', 'Media access needed', 'Нужен доступ к медиа');
  String get mediaAccessBody => _t('Ijro etilayotgan musiqani ko\'rish va boshqarish uchun bildirishnomalarga kirishga ruxsat bering.',
      'Allow notification access to see and control what\'s playing.', 'Разрешите доступ к уведомлениям, чтобы видеть и управлять музыкой.');
  String get allow => _t('Ruxsat berish', 'Allow', 'Разрешить');
  String get openApp => _t('Ilovani ochish', 'Open app', 'Открыть');

  // ---------- Onboarding ----------
  String get welcomeTitle => 'So StandBy';
  String get welcomeSubtitle => _t('Telefoningizni zaryadlash paytida chiroyli\nsoat, ob-havo va media ekraniga aylantiring.',
      'Turn your phone into a beautiful clock,\nweather and media display while charging.',
      'Превратите телефон в красивые часы,\nпогоду и медиа-экран во время зарядки.');
  String get permLocationTitle => _t('Joylashuv', 'Location', 'Геопозиция');
  String get permLocationBody => _t('Shahringizdagi ob-havoni ko\'rsatish uchun', 'To show weather for your city', 'Чтобы показывать погоду в вашем городе');
  String get permMediaTitle => _t('Media boshqaruvi', 'Media Controls', 'Управление медиа');
  String get permMediaBody => _t('Ijro etilayotgan musiqani ko\'rsatish va boshqarish uchun', 'To show and control what\'s playing', 'Чтобы показывать и управлять музыкой');
  String get granted => _t('Yoqilgan', 'On', 'Вкл');
  String get continueBtn => _t('Davom etish', 'Continue', 'Продолжить');
  String get later => _t('Keyinroq', 'Not Now', 'Позже');
  String get privacyNote => _t('Ma\'lumotlaringiz qurilmangizdan tashqariga chiqmaydi.', 'Your data never leaves your device.', 'Ваши данные не покидают устройство.');

  // ---------- Settings ----------
  String get settings => _t('Sozlamalar', 'Settings', 'Настройки');
  String get done => _t('Tayyor', 'Done', 'Готово');
  String get appearance => _t('Ko\'rinish', 'Appearance', 'Оформление');
  String get accent => _t('Rang', 'Color', 'Цвет');
  String get use24h => _t('24 soatlik format', '24-Hour Time', '24-часовой формат');
  String get showSeconds => _t('Sekundlarni ko\'rsatish', 'Show Seconds', 'Показывать секунды');
  String get smoothSeconds => _t('Silliq sekund strelkasi', 'Smooth Second Hand', 'Плавная секундная стрелка');
  String get nightMode => _t('Tungi rejim', 'Night Mode', 'Ночной режим');
  String get nightModeFooter => _t('Tungi rejimda ekran qizil tusga o\'tadi va ko\'zni charchatmaydi. Avto: 22:00 – 06:00. Ekranga bir marta bosib, oy tugmasi orqali ham almashtirish mumkin.',
      'Night Mode tints the display red so it won\'t disturb your sleep. Auto: 22:00 – 06:00. Tap the screen and use the moon button to toggle.',
      'Ночной режим окрашивает экран в красный. Авто: 22:00 – 06:00. Коснитесь экрана и нажмите луну, чтобы переключить.');
  String get off => _t('O\'chiq', 'Off', 'Выкл');
  String get auto => _t('Avto', 'Auto', 'Авто');
  String get on => _t('Yoqiq', 'On', 'Вкл');
  String get weather => _t('Ob-havo', 'Weather', 'Погода');
  String get units => _t('Birlik', 'Units', 'Единицы');
  String get location => _t('Joylashuv', 'Location', 'Местоположение');
  String get currentLocation => _t('Joriy joylashuv', 'Current Location', 'Текущее');
  String get cityHint => _t('Shahar nomi (masalan, Toshkent)', 'City name (e.g. Tashkent)', 'Город (например, Ташкент)');
  String get cityNotFound => _t('Shahar topilmadi', 'City not found', 'Город не найден');
  String get language => _t('Til', 'Language', 'Язык');
  String get display => _t('Ekran', 'Display', 'Экран');
  String get keepAwake => _t('Ekranni yoqiq saqlash', 'Keep Screen On', 'Не выключать экран');
  String get burnIn => _t('Ekranni himoyalash', 'Burn‑in Protection', 'Защита от выгорания');
  String get burnInFooter => _t('Tasvir har daqiqada sezilmas darajada siljiydi.', 'Content shifts slightly every minute.', 'Изображение слегка смещается каждую минуту.');
  String get permissions => _t('Ruxsatlar', 'Permissions', 'Разрешения');
  String get about => _t('Ilova haqida', 'About', 'О приложении');
  String get hintSwipe => _t('Chapga/o\'ngga suring — keyingi ekran', 'Swipe sideways for 13 views · up/down on Clock for 10 styles', 'Листайте влево/вправо');
  String get hintClockStyles => _t('Yuqoriga/pastga — soat uslubi', 'Swipe up/down for clock styles', 'Вверх/вниз — стиль часов');
  String get hintLongPress => _t('Uzoq bosing — sozlamalar', 'Long‑press for settings', 'Удерживайте — настройки');
  String get refresh => _t('Yangilash', 'Refresh', 'Обновить');
}
