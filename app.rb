require 'sinatra'
set :protection, except: :host_authorization
require 'telegram/bot'
require 'json'
require 'dotenv/load'
require 'logger'

set :bind, '0.0.0.0'
set :port, ENV['PORT'] || 4567

# Логування
LOG_FILE = ENV['LOG_FILE'] || 'bot.log'
logger = Logger.new(LOG_FILE)
logger.level = Logger::INFO
logger.formatter = proc do |severity, datetime, progname, msg|
  "#{datetime.strftime('%Y-%m-%d %H:%M:%S')} [#{severity}] #{msg}\n"
end

# Константи
BOT_TOKEN = ENV['BOT_TOKEN']
ADMIN_CHAT_ID = ENV['ADMIN_CHAT_ID']
MAX_RETRIES = 3
RETRY_DELAY = 5
$user_sessions = {}

# Мови
LANGUAGES = {
  'uk' => {
    name: '🇺🇦 Українська',
    welcome: 'Вітаємо! Оберіть мову:',
    menu_title: '📋 Наше меню:',
    cart_title: '🛒 Ваш кошик:',
    cart_empty: 'Кошик порожній',
    add_to_cart: 'Додано до кошика!',
    remove_from_cart: 'Видалено з кошика!',
    order_button: '🛒 Кошик',
    back_button: '⬅️ Назад',
    clear_cart: '🗑 Очистити кошик',
    make_order: '📝 Оформити замовлення',
    enter_phone: 'Введіть ваш номер телефону:',
    enter_address: 'Введіть вашу адресу доставки:',
    order_summary: "📋 Підтвердження замовлення:\n\n",
    total: 'Загальна сума: ',
    phone: 'Телефон: ',
    address: 'Адреса: ',
    confirm_order: '✅ Підтвердити замовлення',
    order_sent: 'Замовлення відправлено! Очікуйте на дзвінок.',
    new_order: 'Нове замовлення',
    share_phone: '📱 Поділитися номером',
    error_occurred: 'Виникла помилка. Спробуйте ще раз або зверніться до підтримки.',
    delivery: 'Вартість доставки'
  },
  'pl' => {
    name: '🇵🇱 Polski',
    welcome: 'Witamy! Wybierz język:',
    menu_title: '📋 Nasze menu:',
    cart_title: '🛒 Twój koszyk:',
    cart_empty: 'Koszyk jest pusty',
    add_to_cart: 'Dodano do koszyka!',
    remove_from_cart: 'Usunięto z koszyka!',
    order_button: '🛒 Koszyk',
    back_button: '⬅️ Wstecz',
    clear_cart: '🗑 Wyczyść koszyk',
    make_order: '📝 Złóż zamówienie',
    enter_phone: 'Wprowadź numer telefonu:',
    enter_address: 'Wprowadź adres dostawy:',
    order_summary: "📋 Potwierdzenie zamówienia:\n\n",
    total: 'Suma całkowita: ',
    phone: 'Telefon: ',
    address: 'Adres: ',
    confirm_order: '✅ Potwierdź zamówienie',
    order_sent: 'Zamówienie wysłane! Oczekuj na telefon.',
    new_order: 'Nowe zamówienie',
    share_phone: '📱 Udostępnij numer',
    error_occurred: 'Wystąpił błąd. Spróbuj ponownie lub skontaktuj się z pomocą.',
    delivery: 'Koszt dostawy'
  },
  'en' => {
    name: '🇬🇧 English',
    welcome: 'Welcome! Choose language:',
    menu_title: '📋 Our menu:',
    cart_title: '🛒 Your cart:',
    cart_empty: 'Cart is empty',
    add_to_cart: 'Added to cart!',
    remove_from_cart: 'Removed from cart!',
    order_button: '🛒 Cart',
    back_button: '⬅️ Back',
    clear_cart: '🗑 Clear cart',
    make_order: '📝 Place order',
    enter_phone: 'Enter your phone number:',
    enter_address: 'Enter your delivery address:',
    order_summary: "📋 Order confirmation:\n\n",
    total: 'Total amount: ',
    phone: 'Phone: ',
    address: 'Address: ',
    confirm_order: '✅ Confirm order',
    order_sent: 'Order sent! Expect a call.',
    new_order: 'New order',
    share_phone: '📱 Share phone',
    error_occurred: 'An error occurred. Please try again or contact support.',
    delivery: 'Delivery cost'
  },
  'ru' => {
    name: '🇷🇺 Русский',
    welcome: 'Добро пожаловать! Выберите язык:',
    menu_title: '📋 Наше меню:',
    cart_title: '🛒 Ваша корзина:',
    cart_empty: 'Корзина пуста',
    add_to_cart: 'Добавлено в корзину!',
    remove_from_cart: 'Удалено из корзины!',
    order_button: '🛒 Корзина',
    back_button: '⬅️ Назад',
    clear_cart: '🗑 Очистить корзину',
    make_order: '📝 Оформить заказ',
    enter_phone: 'Введите номер телефона:',
    enter_address: 'Введите адрес доставки:',
    order_summary: "📋 Подтверждение заказа:\n\n",
    total: 'Общая сумма: ',
    phone: 'Телефон: ',
    address: 'Адрес: ',
    confirm_order: '✅ Подтвердить заказ',
    order_sent: 'Заказ отправлен! Ожидайте звонка.',
    new_order: 'Новый заказ',
    share_phone: '📱 Поделиться номером',
    error_occurred: 'Произошла ошибка. Попробуйте еще раз или обратитесь в поддержку.',
    delivery: 'Стоимость доставки'
  },
  'by' => {
    name: '🇧🇾 Беларуская',
    welcome: 'Вітаем! Выберыце мову:',
    menu_title: '📋 Наша мэню:',
    cart_title: '🛒 Ваша кошык:',
    cart_empty: 'Кошык пусты',
    add_to_cart: 'Дададзена ў кошык!',
    remove_from_cart: 'Выдалена з кошыка!',
    order_button: '🛒 Кошык',
    back_button: '⬅️ Назад',
    clear_cart: '🗑 Ачысціць кошык',
    make_order: '📝 Аформіць замову',
    enter_phone: 'Увядзіце нумар тэлефона:',
    enter_address: 'Увядзіце адрас дастаўкі:',
    order_summary: "📋 Пацвярджэнне замовы:\n\n",
    total: 'Агульная сума: ',
    phone: 'Тэлефон: ',
    address: 'Адрас: ',
    confirm_order: '✅ Пацвердзіць замову',
    order_sent: 'Замова адпраўлена! Чакайце званка.',
    new_order: 'Новая замова',
    share_phone: '📱 Падзяліцца нумарам',
    error_occurred: 'Узнікла памылка. Паспрабуйце яшчэ раз або звярніцеся ў падтрымку.',
    delivery: 'Кошт дастаўкі'
  }
}


MENU_ITEMS = [
  { id: 1, name_uk: 'Вареники з вишнею', name_pl: 'Pierogi z wiśniami', name_en: 'Dumplings with cherries', name_ru: 'Вареники с вишней', name_by: 'Варэнікі з вішняй', price: 38 },
  { id: 2, name_uk: 'Вареники з картоплею', name_pl: 'Kluski z ziemniakami', name_en: 'Dumplings with potatoes', name_ru: 'Вареники с картофелем', name_by: 'Варэнікі з бульбай', price: 38 },
  { id: 3, name_uk: 'Вареники з полуницею та м\'ятою', name_pl: 'Pierogi z truskawkami i miętą', name_en: 'Dumplings with strawberries and mint', name_ru: 'Вареники с клубникой и мятой', name_by: 'Варэнікі з трускаўкай і мятай', price: 38 },
  { id: 4, name_uk: 'Вареники з солодким творогом', name_pl: 'Pierogi z serem na słodko', name_en: 'Dumplings with sweet cottage cheese', name_ru: 'Вареники со сладким творогом', name_by: 'Варэнікі з салодкім тварагом', price: 38 },
  { id: 5, name_uk: 'Вареники з солоним творогом', name_pl: 'Pierogi z serem solonym', name_en: 'Dumplings with salted cottage cheese', name_ru: 'Вареники с соленым творогом', name_by: 'Варэнікі з салёным тварагом', price: 38 },
  { id: 6, name_uk: 'Вареники з телятиною та м\'ятою', name_pl: 'Pierogi z cielęciną i miętą', name_en: 'Dumplings with veal and mint', name_ru: 'Вареники с телятиной и мятой', name_by: 'Варэнікі з цяляцінай і мятай', price: 38 },
  { id: 7, name_uk: 'Пельмені зі свининою', name_pl: 'Pielmieni z wieprzowiną', name_en: 'Pork dumplings', name_ru: 'Пельмени со свининой', name_by: 'Пельмені са свініны', price: 38 }
]

def get_user_session(user_id)
    $user_sessions[user_id] ||= { language: nil, cart: [], state: :start, phone: nil, address: nil }
end
  
def get_text(user_id, key)
    session = get_user_session(user_id)
    lang = session[:language] || 'uk'
    LANGUAGES[lang][key]
end
  
def get_menu_item_name(item, language)
    case language
    when 'uk' then item[:name_uk]
    when 'pl' then item[:name_pl]
    when 'en' then item[:name_en]
    when 'ru' then item[:name_ru]
    when 'by' then item[:name_by]
    else item[:name_en]
    end
end
  
  # Клавіатури
  def language_selection_keyboard
    kb = LANGUAGES.map do |code, lang|
      [Telegram::Bot::Types::InlineKeyboardButton.new(text: lang[:name], callback_data: "lang_#{code}")]
    end
    Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
  end
  
  def main_menu_keyboard(user_id)
    lang = get_user_session(user_id)[:language]
    kb = MENU_ITEMS.map do |item|
      [Telegram::Bot::Types::InlineKeyboardButton.new(
        text: "#{get_menu_item_name(item, lang)} - #{item[:price]}₴",
        callback_data: "add_#{item[:id]}"
      )]
    end
    kb << [Telegram::Bot::Types::InlineKeyboardButton.new(text: get_text(user_id, :order_button), callback_data: "cart")]
    kb << [Telegram::Bot::Types::InlineKeyboardButton.new(text: "🌐 Змінити мову", callback_data: "change_language")]
    Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
  end
  
  def cart_keyboard(user_id)
    kb = []
    session = get_user_session(user_id)
    lang = session[:language]
    session[:cart].each do |item_id|
      item = MENU_ITEMS.find { |i| i[:id] == item_id }
      kb << [Telegram::Bot::Types::InlineKeyboardButton.new(
        text: "❌ #{get_menu_item_name(item, lang)}",
        callback_data: "remove_#{item_id}"
      )]
    end
    kb << [Telegram::Bot::Types::InlineKeyboardButton.new(text: get_text(user_id, :make_order), callback_data: "make_order")] unless session[:cart].empty?
    kb << [Telegram::Bot::Types::InlineKeyboardButton.new(text: get_text(user_id, :clear_cart), callback_data: "clear_cart")]
    kb << [Telegram::Bot::Types::InlineKeyboardButton.new(text: get_text(user_id, :back_button), callback_data: "back_to_menu")]
    Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
  end
  
  def phone_request_keyboard(user_id)
    kb = [
      [Telegram::Bot::Types::KeyboardButton.new(text: get_text(user_id, :share_phone), request_contact: true)]
    ]
    Telegram::Bot::Types::ReplyKeyboardMarkup.new(keyboard: kb, resize_keyboard: true, one_time_keyboard: true)
  end
  
  def order_confirmation_keyboard(user_id)
    kb = [
      [Telegram::Bot::Types::InlineKeyboardButton.new(text: get_text(user_id, :confirm_order), callback_data: "confirm_order")]
    ]
    Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
  end
  
  def format_cart(user_id)
    session = get_user_session(user_id)
    lang = session[:language]
    text = ""
    total = 0
    session[:cart].each do |item_id|
      item = MENU_ITEMS.find { |i| i[:id] == item_id }
      text += "#{get_menu_item_name(item, lang)} - #{item[:price]}₴\n"
      total += item[:price]
    end
    text = get_text(user_id, :cart_empty) if text.empty?
    text += "\n#{get_text(user_id, :total)} #{total}₴" unless total.zero?
    text
  end
  

post '/webhook' do
  request_data = JSON.parse(request.body.read)
  logger.info("Received update: #{request_data}")

  if request_data['message']
    handle_message(request_data['message'])
  elsif request_data['callback_query']
    handle_callback(request_data['callback_query'])
  end

  status 200
  end

def handle_message(message)
  user_id = message['from']['id']
  session = get_user_session(user_id)

  if message['contact']
    session[:phone] = message['contact']['phone_number']
    send_message(user_id, get_text(user_id, :enter_address))
    session[:state] = :waiting_for_address
  elsif session[:state] == :waiting_for_address
    session[:address] = message['text']
    send_order_summary(user_id)
  else
    send_message(user_id, get_text(user_id, :welcome), language_selection_keyboard)
  end
end

def handle_callback(callback)
  user_id = callback['from']['id']
  data = callback['data']
  session = get_user_session(user_id)

  if data.start_with?('lang_')
    session[:language] = data.split('_')[1]
    send_message(user_id, get_text(user_id, :menu_title), main_menu_keyboard(user_id))
  elsif data.start_with?('add_')
    session[:cart] << data.split('_')[1].to_i
    answer_callback(callback['id'], get_text(user_id, :add_to_cart))
  elsif data.start_with?('remove_')
    item_id = data.split('_')[1].to_i
    session[:cart].delete_at(session[:cart].index(item_id) || session[:cart].length)
    send_message(user_id, format_cart(user_id), cart_keyboard(user_id))
  elsif data == 'cart'
    send_message(user_id, format_cart(user_id), cart_keyboard(user_id))
  elsif data == 'clear_cart'
    session[:cart].clear
    send_message(user_id, get_text(user_id, :cart_empty), cart_keyboard(user_id))
  elsif data == 'make_order'
    send_message(user_id, get_text(user_id, :enter_phone), phone_request_keyboard(user_id))
  elsif data == 'confirm_order'
    send_message(user_id, get_text(user_id, :order_sent))
    notify_admin(user_id)
    session[:cart].clear
  elsif data == 'back_to_menu'
    send_message(user_id, get_text(user_id, :menu_title), main_menu_keyboard(user_id))
  elsif data == 'change_language'
    send_message(user_id, get_text(user_id, :welcome), language_selection_keyboard)
  else
    answer_callback(callback['id'], "Unknown command")
  end
end

def send_message(chat_id, text, reply_markup = nil)
  Telegram::Bot::Client.run(BOT_TOKEN) do |bot|
    bot.api.send_message(chat_id: chat_id, text: text, reply_markup: reply_markup)
  end
end

def answer_callback(callback_query_id, text)
  Telegram::Bot::Client.run(BOT_TOKEN) do |bot|
    bot.api.answer_callback_query(callback_query_id: callback_query_id, text: text, show_alert: false)
  end
end

def send_order_summary(user_id)
  session = get_user_session(user_id)
  text = get_text(user_id, :order_summary) + format_cart(user_id) + "\n"
  text += "#{get_text(user_id, :phone)} #{session[:phone]}\n"
  text += "#{get_text(user_id, :address)} #{session[:address]}\n"
  send_message(user_id, text, order_confirmation_keyboard(user_id))
end

def notify_admin(user_id)
  session = get_user_session(user_id)
  text = "#{get_text(user_id, :new_order)}\n" + format_cart(user_id) + "\n"
  text += "#{get_text(user_id, :phone)} #{session[:phone]}\n"
  text += "#{get_text(user_id, :address)} #{session[:address]}\n"
  Telegram::Bot::Client.run(BOT_TOKEN) do |bot|
    bot.api.send_message(chat_id: ADMIN_CHAT_ID, text: text)
  end
end