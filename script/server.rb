require 'webrick'
require 'listen'
require 'faye/websocket'
require 'json'

# WebSocket server
class WebSocketServer
  KEEPALIVE_TIME = 15 # in seconds

  def initialize
    @clients = []
  end

  def call(env)
    if Faye::WebSocket.websocket?(env)
      ws = Faye::WebSocket.new(env, nil, { ping: KEEPALIVE_TIME })

      ws.on :open do |event|
        @clients << ws
      end

      ws.on :close do |event|
        @clients.delete(ws)
        ws = nil
      end

      ws.rack_response
    else
      [404, { 'Content-Type' => 'text/plain' }, ['Not Found']]
    end
  end

  def notify_clients
    @clients.each do |ws|
      ws.send({ action: 'reload' }.to_json)
    end
  end
end

# HTTP server
root = File.expand_path('../public', __dir__)
server = WEBrick::HTTPServer.new(Port: 3000, DocumentRoot: root)

# WebSocket server
ws_server = WebSocketServer.new
server.mount '/ws', ws_server

# Listen to file changes
listener = Listen.to(root, only: /main\.rb/) do |_modified, _added, _removed|
  ws_server.notify_clients
end
listener.start

trap 'INT' do
  server.shutdown
end

server.start