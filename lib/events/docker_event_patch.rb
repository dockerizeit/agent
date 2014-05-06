# Monkey patch the Event class to allow JSON serialization
class Docker::Event
  def json
    { 'status' => @status, 'id' => @id, 'from' => @from, 'time' => @time }
  end
end
