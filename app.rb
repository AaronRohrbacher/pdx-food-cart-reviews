require("bundler/setup")
Bundler.require(:default)
require("pry")
# sessions provide a way to keep track of who's logged in
enable :sessions

Dir[File.dirname(__FILE__) + '/lib/*.rb'].each { |file| require file }

# Defines authenticated users that are logged in
helpers do
  def current_user
    if session[:user_id]
      User.find { |u| u.id == session[:user_id] }
    else
      nil
    end
  end
end

get '/sign_in' do
  erb :sign_in
end

post '/sign_in' do
  user = User.find { |u| u.username == params["username"] }
  if user && user.auth_pass(params["pass"])
    # session.clear
    session[:user_id] = user.id
    redirect '/'
  else
    @error = 'Username or password was incorrect'
    erb :sign_in
  end
end

# TODO ONLY clear a specific user's session
get '/sign_out' do
  session.clear
  redirect back
end

get('/') do
  @carts = Cart.all
  @featured_reviews = Review.all.where("rating >= 4").sample(3)
  erb(:index)
end

get '/cart_checker/:gp_id' do
  cart = Cart.find {|c| c.gp_id == params[:gp_id]}
  if cart != nil
    redirect "/cart/#{cart.id}"
  else
    quick_add = Cart.new({:gp_id => params[:gp_id], :is_confirmed => true, :tag => nil})
    quick_add.save
    redirect "/cart/#{quick_add.id}"
  end
end

get('/carts') do
  @carts = Cart.all
  erb(:cart)
end

get('/cart/:id') do
  @cart = Cart.find(params[:id])
  @reviews = @cart.reviews
  erb(:cart_reviews)
end

post '/cart/:id' do
  redirect "/cart/#{params["cart"]}"
end

post "/results" do
  redirect "/results/#{params["search"].split(" ").join("_")}"
end


get '/results/:search' do
  @results = GooglePlaces::Client.new('AIzaSyBb-6lyykgnZhSEv_FdW6BWi_7BjznhOmw').spots_by_query(params[:search].split(" ").join("_") + ' food cart Portland Oregon')
  erb :results
end

get('/review/:cart_id') do
  if current_user
    @cart = Cart.find(params['cart_id'])
    erb(:new_review)
  else
    redirect '/sign_in'
  end
end

post('/review/:cart_id') do
  if current_user
    new_review = Review.new(food_name: params['food'], price: params['price'], review: params['review'], cart_id: params['cart_id'], rating: params['rating'], user_id: current_user.id)
    if new_review.save
      @cart = Cart.find(params['cart_id'])
      @reviews = @cart.reviews
      @carts = Cart.all
      erb(:cart)
    else
      redirect "/review/#{:cart_id}"
    end
  else
    redirect '/sign_in'
  end
end

get('/review/view/:review_id') do
  @review = Review.find(params['review_id'])
  erb(:review)
end

get '/:user_id/reviews' do
  @user = User.find(params[:user_id])
  erb :my_reviews
end

get '/edit/:review_id' do
  @review = Review.find(params[:review_id])
  erb :update_review
end

patch '/edit/:review_id' do
  if current_user
    review = Review.find(params[:review_id])
    # CODE that protected unselected stars on a review update
    # if params['rating'] == nil
    #   params['rating'] = review.rating
    # end
    review.update(food_name: params['food'], price: params['price'], review: params['review'], rating: params['rating'])
    redirect "/#{current_user.id}/reviews"
  else
    redirect '/sign_in'
  end
end

get '/delete/:review_id' do
  @review = Review.find(params[:review_id])
  erb :delete_review
end

delete '/delete/:review_id' do
  review = Review.find(params[:review_id])
  user_id = review.user_id
  if current_user
    Review.find(params[:review_id]).destroy
    redirect "/#{user_id}/reviews"
  else
    redirect '/sign_in'
  end
end

post '/user' do
  name = params['first_name'] + " " + params['last_name']
  user = User.new(name: name, email: params['email'], username: params['username'], pass: params['password'])
  if user.save
    redirect '/'
  else
    @errors = user.errors.full_messages()
    erb :sign_in
  end
end
