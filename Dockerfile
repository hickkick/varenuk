
FROM ruby:3.4.1


# Створюємо робочу директорію
WORKDIR /app

# Копіюємо файли
COPY . .

# Встановлюємо залежності
RUN gem install bundler && bundle install

# Порт для прослуховування (той, що ти вказав у Railway)
ENV PORT=8080
EXPOSE 8080

# Запуск серверу
CMD ["ruby", "app.rb"]
