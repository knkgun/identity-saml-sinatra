require 'erb'
require 'net/http'
require 'sinatra/base'
require 'onelogin/ruby-saml'
require 'ostruct'
require 'yaml'
# require_relative 'app/saml_settings'

class RelyingParty < Sinatra::Base
  def init(uri)
    @auth_server_uri = uri
  end

  def auth_server_uri
    @auth_server_uri ||= URI('https://localhost:1234')
  end

  get '/' do
    agency = params[:agency]
    whitelist = ['uscis']

    if whitelist.include?(agency)
      erb :"agency/#{agency}", :layout => false
    else
      erb :index
    end
  end

  post '/login/?' do
    # begin
      puts 'Login received'
      request = OneLogin::RubySaml::Authrequest.new
      puts "Request: #{request}"
      x = saml_settings
      redirect to(request.create(saml_settings))
    # rescue
    #   Fake a success for now
    #   call env.merge("PATH_INFO" => '/success', "REQUEST_METHOD" => 'GET')
    # end
  end

  get '/success/?' do
    erb :success
  end

  post '/consume/?' do
    puts "params: #{params}"
    response = OneLogin::RubySaml::Response.new(params[:SAMLResponse])

    # insert identity provider discovery logic here
    response.settings = Account.get_saml_settings

    puts "NAMEID: #{response.name_id}"

    if response.is_valid?
      session[:userid] = response.name_id
      puts 'Success!'
      redirect_to :action => :complete
    else
      puts 'Fail :('
      redirect_to :action => :fail
    end
  end

  private

  def saml_settings
    settings = OpenStruct.new(YAML.load_file 'config/saml_settings.yml')
    settings[:certificate] = File.read('config/server.crt')
    settings[:private_key] = File.read('config/server.key')
    settings[:idp_cert] =  File.read('config/idp.crt')
    settings
  end

  run! if app_file == $0
end
