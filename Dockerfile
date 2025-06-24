FROM ruby:3.4.1

WORKDIR /app

COPY . .

RUN gem install bundler
RUN bundle install

ENV PORT=8080
EXPOSE 8080

CMD bundle exec rake db:migrate && ruby app.rb