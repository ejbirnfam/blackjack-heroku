require 'rubygems'
require 'sinatra'

set :sessions, true

BLACKJACK_AMOUNT = 21
DEALER_MIN_HIT = 17
INITIAL_POT_AMOUNT = 500

helpers do
  def calculate_total(cards)
    values = cards.map { |suit, value| value }
    total = 0
    values.each do |value|
      if value == "J" || value == "Q" || value == "K"
        total += 10
      elsif value == "A"
        total += 11
      else
        total += value.to_i
      end
    end
    values.select{ |value| value == "A"}.count.times do
      if total > BLACKJACK_AMOUNT
        total -= 10
      end
    end
    total
  end

  def card_image(card) # ['H', '4']
    suit = case card[0]
      when 'H' then 'hearts'
      when 'D' then 'diamonds'
      when 'C' then 'clubs'
      when 'S' then 'spades'
    end

    value = card[1]
    if ['J', 'Q', 'K', 'A'].include?(value)
      value = case card[1]
        when 'J' then 'jack'
        when 'Q' then 'queen'
        when 'K' then 'king'
        when 'A' then 'ace'
      end
    end

    "<img src='/images/cards/#{suit}_#{value}.jpg' class='card_image'>"
  end

  def winner!(msg)
    @play_again = true
    @show_hit_or_stay_buttons = false
    session[:player_money] = session[:player_money] + session[:player_bet]
    @winner = "#{session[:player_name]} won.  #{msg}"
  end

  def loser!(msg)
    @play_again = true
    @show_hit_or_stay_buttons = false
    session[:player_money] = session[:player_money] - session[:player_bet]
    @loser = "#{session[:player_name]} lost.  #{msg}"
  end

  def tie!(msg)
    @play_again = true
    @show_hit_or_stay_buttons = false
    @winner = "It's a tie.  #{msg}"
  end
end

before do
  @show_hit_or_stay_buttons = true
end

get '/' do
  if session[:player_name]
    redirect '/game'
  else   
    redirect '/set_name'
  end
end

get '/set_name' do
  session[:player_money] = INITIAL_POT_AMOUNT
  erb :set_name
end

post '/set_name' do
  if params[:player_name].empty?
    @error = "Name is required"
    halt erb(:set_name)
  end
  session[:player_name] = params[:player_name]
  redirect '/bet'
end

get '/bet' do
  session[:player_bet] = nil
  erb :bet
end

post '/bet' do
  if params[:bet_amount].nil? || params[:bet_amount].to_i == 0
    @error = "Must make a bet."
    halt erb(:bet)
  elsif params[:bet_amount].to_i > session[:player_money]
    @error = "Bet amount cannot be greater than total amount of player money."
    halt erb(:bet)
  else
    session[:player_bet] = params[:bet_amount].to_i
    redirect '/game'
  end
end

get '/game' do
  session[:turn] = session[:player_name]
  suits = ['D', 'H', 'S', 'C']
  cards = ['A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K']
  session[:deck] = suits.product(cards).shuffle!
  session[:player_cards] = []
  session[:dealer_cards] = []
  session[:player_cards] << session[:deck].pop
  session[:dealer_cards] << session[:deck].pop
  session[:player_cards] << session[:deck].pop
  session[:dealer_cards] << session[:deck].pop
  session[:player_total] = calculate_total(session[:player_cards])
  session[:dealer_total] = calculate_total(session[:dealer_cards])
  erb :game
end

post '/hit' do
  session[:player_cards] << session[:deck].pop
  session[:player_total] = calculate_total(session[:player_cards])
  if session[:player_total] == BLACKJACK_AMOUNT
    winner!("#{session[:player_name]} hit Blackjack.  Everyone gets lucky once in awhile.  You won #{player_bet}, bringing your total money to #{player_money}.  I bet you can't do that again.")
  elsif session[:player_total] > BLACKJACK_AMOUNT
    loser!("#{session[:player_name]} Busted.  I don't even feel challenged.  You lose #{player_bet}, bringing your total money down to a tiny #{player_money}.")
  end
  erb :game, layout: false
end

post '/stay' do
  @success = "#{session[:player_name]} has chosen to stay.  You'll probably lose."
  @show_hit_or_stay_buttons = false
  redirect '/dealer'
end

get '/dealer' do
  session[:turn] = 'Dealer'
  @show_hit_or_stay_buttons = false
  dealer_total = calculate_total(session[:dealer_cards])
  if dealer_total == BLACKJACK_AMOUNT
    loser!("Dealer hits blackjack.  You are bad at this.  You lose #{player_bet}, bringing your total money down to a tiny #{player_money}.")
  elsif dealer_total > BLACKJACK_AMOUNT
    winner!("Dealer busted at #{dealer_total}.  You got lucky and won #{player_bet}, bringing your total money to #{player_money}.  I bet you can't do that again.")
  elsif dealer_total >= DEALER_MIN_HIT
    redirect '/compare'
  else
    @show_dealer_hit_button = true
  end
  erb :game, layout: false
end

post '/dealer_hit' do
  session[:dealer_cards] << session[:deck].pop
  redirect '/dealer'
end

get '/compare' do
  @show_hit_or_stay_buttons = false
  player_total = calculate_total(session[:player_cards])
  dealer_total = calculate_total(session[:dealer_cards])
  if player_total < dealer_total
    loser!("#{session[:player_name]} stayed at #{player_total}, and the dealer stayed at #{dealer_total}.  Are you smart enough to know which number is bigger?  Shocking no one, you lose #{player_bet}, bringing your total money to a pathetic #{player_money}.")
  elsif player_total > dealer_total
    winner!("#{session[:player_name]} stayed at #{player_total}, and the dealer stayed at #{dealer_total}.  You got lucky this time and won #{player_bet}, bringing your total money to #{player_money}.")
  else
    tie!("Both #{session[:player_name]} and the dealer stayed at #{player_total}.  While you didn't lose any money, you didn't win any either.  Your total money is still #{player_money}.")
  end
  erb :game, layout: false
end

get '/game_over' do
  erb :game_over
end