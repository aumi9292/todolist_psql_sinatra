
class SessionPersistence

  def initialize(session)
    @session = session 
    @session[:lists] ||= []
  end 

  def find_list(id)
    @session[:lists].find { |list| list[:id] == id }
  end 

  def all_lists
    @session[:lists] 
  end 

  def create_new_list(list_name) 
    id = next_list_id(@session[:lists])
    @session[:lists] << { id: id, name: list_name, todos: [] }
  end 

  def update_list_name(id, new_name)
    list = find_list(id) 
    list[:name] = new_name 
  end 

  def create_new_todo(list_id, todo_name)
    list = find_list(list_id)
    id = next_todo_id(list)
    list[:todos] << { id: id, name: todo_name, completed: false }
  end

  def delete_todo_from_list(list_id, todo_id)
    list = find_list(list_id)
    list[:todos].delete_at(todo_id)
  end 

  def update_todo_status(list_id, todo_id, status)
    list = find_list(list_id)
    todo = list[:todos].find { |todo| todo[:id] == todo_id }
    todo[:completed] = status
  end 

  

  def session_error=(message)
    @session[:error] = message
  end 

  def session_success=(message)
    @session[:success] = message 
  end 

  def reject_list(id)
    all_lists.reject! { |list| list[:id] == id }
  end 

  def mark_all_todos_complete(list_id)
    list = find_list(list_id)
    list[:todos].each { |todo| todo[:completed] = true }
  end 

  private 

  def next_list_id(lists)
    max = lists.map { |list| list[:id] }.max || 0 
    max + 1
  end

  def next_todo_id(list)
    max = list[:todos].map { |todo| todo[:id] }.max || 0
    max + 1 
  end 
end 