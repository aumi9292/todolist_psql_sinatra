require "sinatra"

require "tilt/erubis"
require 'sinatra/content_for'
require_relative "database_persistence"

LENGTH_ERR = "This must be between 1 and 100 characters."
UNIQUE_ERR = "The list name must be unique"

configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, :escape_html => true
end

configure(:development) do 
  require "sinatra/reloader"
  also_reload "database_persistence.rb" 
end 

before do
  @storage = DatabasePersistence.new(logger)
end

after do 
  @storage.disconnect 
end 

helpers do

  def complete_conditions?(list)
    list[:todos_count] >= 1 && list[:todos_remaining_count] == 0
  end 

  def sort_lists(lists, &block)
    complete_lists, incomplete_lists = lists.partition { |list| complete_conditions?(list) }

    incomplete_lists.each(&block)
    complete_lists.each(&block)
  end

  def sort_todos(todos, &block)

    complete_todos, incomplete_todos = todos.partition { |todo| complete?(todo) }

    incomplete_todos.each { |todo| yield todo, todos.index(todo) } 
    complete_todos.each { |todo| yield todo, todos.index(todo) }

  end 

  def todo_complete_sort(todos)
    todos.sort_by do |todo|
      todo[:completed] ? 1 : 0
    end 
  end 

  def complete?(todo)
    todo[:completed] == true
  end 

  def list_size(list)
    list[:todos].size
  end 

  def list_completed(list)
    'class="complete"' if complete_conditions?(list)
  end 

  def unique_list_names?
    @storage.all_lists.none? { |list| list[:name] == params[:list_name] }
  end

  def valid_list_length?
    params[:list_name].strip.size.between?(1, 100)
  end

  def error_for_list_name
    return LENGTH_ERR unless valid_list_length?
    return UNIQUE_ERR unless unique_list_names?
  end

  def valid_todo_length?(txt)
    txt.size.between?(1, 100)
  end 

  def error_for_todo(txt)
    return LENGTH_ERR unless valid_todo_length?(txt) 
  end 
end

not_found do 
  redirect "/lists"
end 

get "/" do
  redirect "/lists"
end

# view all lists
get "/lists" do
  @lists = @storage.all_lists
  erb :lists, layout: :layout
end

# Renders new list form
get "/lists/new" do
  erb :new_list, layout: :layout
end

# creates a new list
post "/lists" do
  @lists = @storage.all_lists
  error = error_for_list_name

  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else

    @storage.create_new_list(params[:list_name])
    session[:success] = "The list has been created."
    redirect "/lists"
  end
end


def load_list(id)
  list = @storage.find_list(id) 
  return list if list 

  session[:error] = "The list was not found"
  redirect "/lists"
end 

#view single list 
get "/lists/:id" do 
  @lists = @storage.all_lists
  @list_id = params[:id].to_i
  @list = load_list(@list_id)
  @todos = @storage.list_all_todos(@list_id)
  erb :list, layout: :layout
end 

#edit existing todo list 
get "/lists/:id/edit" do 
  @list_id = params[:id].to_i
  @list = load_list(@list_id)
  erb :edit_list, layout: :layout 
end 

# update existing to do list 
post "/lists/:id" do 
  
  @id = params[:id].to_i
  @list = load_list(@id)
  error = error_for_list_name

  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @storage.update_list_name(@id, params[:list_name].strip)
    session[:success] = "The list has successfully been modified."
    redirect "/lists/#{@id}"
  end
end 

#remove list from session[:lists] array 
post "/lists/:id/delete" do 
  id = params[:id].to_i
  @storage.reject_list(id)
  
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    session[:success] = "The list has been deleted."
    "/lists" 
  else 
    session[:success] = "The list has been deleted."
    redirect "/lists"
  end 
end 

#add new todo to list 
post "/lists/:list_id/todos" do 
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  @todos = @storage.list_all_todos(@list)
  text = params[:todo].strip

  error = error_for_todo(text)

  if error 
    session[:error] = error
    erb :list, layout: :layout
  else 
    @storage.create_new_todo(@list_id, text)
    session[:success] = "The todo was added!"
    redirect "/lists/#{@list[:id]}"
  end 
end 

#delete todo item
post "/lists/:list_id/todos/:todo_id/delete" do 
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  @todo_id = params[:todo_id].to_i 
  @storage.delete_todo_from_list(@list_id, @todo_id)

  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    status 204 
  else 
    session[:success] = "The todo was deleted!"
    redirect "/lists/#{@list[:id]}"
  end 
end 

#mark todo complete or incomplete
post "/lists/:list_id/todos/:todo_id" do 
  @is_completed = params[:completed] == "true"
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  @todo_id = params[:todo_id].to_i
  @storage.update_todo_status(@list_id, @todo_id, @is_completed)

  session[:success] = "The todo has been updated"
  redirect "/lists/#{@list_id}"
end 

#mark all todos as complete
post "/lists/:list_id/complete_all" do 
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  @todo_id = params[:todo_id].to_i 
  @storage.mark_all_todos_complete(@list_id)
  session[:success] = "All todos have been updated"
  redirect "/lists/#{@list_id}"
end 