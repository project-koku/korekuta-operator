import http.server
import ssl

httpd = http.server.HTTPServer(
    ('localhost', 4443), http.server.SimpleHTTPRequestHandler)
httpd.socket = ssl.wrap_socket(
    httpd.socket, certfile='./mock_reporting_api.pem', server_side=True)
httpd.serve_forever()
