require 'sinatra/base'
require 'nokogiri'
require 'builder'
require_relative '../services/service'

class InstrumentoSoapService < Sinatra::Base
  def initialize
    super
    @service = InstrumentoService.new
  end

  configure do
    set :show_exceptions, false
  end

  # Endpoint principal - maneja tanto SOAP como WSDL
  get '/' do
    if params[:wsdl] || request.query_string.include?('wsdl')
      content_type 'text/xml; charset=utf-8'
      generate_wsdl
    else
      content_type 'text/plain'
      'Instrumentos SOAP Service - Use POST for SOAP requests or add ?wsdl for WSDL'
    end
  end

  # Endpoint principal SOAP
  post '/' do
    content_type 'text/xml; charset=utf-8'
    
    begin
      # Parsear el XML SOAP recibido
      soap_body = request.body.read
      doc = Nokogiri::XML(soap_body)
      
      # Extraer el nombre de la operación
      operation = extract_operation(doc)
      
      case operation
      when 'CreateInstrumento'
        handle_create_instrumento(doc)
      when 'GetInstrumentoById'
        handle_get_instrumento_by_id(doc)
      when 'GetInstrumentosByName'
        handle_get_instrumentos_by_name(doc)
      when 'UpdateInstrumento'
        handle_update_instrumento(doc)
      when 'DeleteInstrumento'
        handle_delete_instrumento(doc)
      else
        soap_fault("Operación no soportada: #{operation}")
      end
    rescue => e
      soap_fault(e.message)
    end
  end

  private

  def extract_operation(doc)
    # Buscar el primer elemento dentro del Body
    body = doc.at_xpath('//soap:Body', 'soap' => 'http://schemas.xmlsoap.org/soap/envelope/') ||
           doc.at_xpath('//Body') ||
           doc.at_xpath('//*[local-name()="Body"]')
    
    return nil unless body
    
    operation_element = body.children.find { |child| child.name != 'text' && !child.text.strip.empty? }
    operation_element&.name
  end

  def extract_params(doc, operation)
    body = doc.at_xpath('//soap:Body', 'soap' => 'http://schemas.xmlsoap.org/soap/envelope/') ||
           doc.at_xpath('//Body') ||
           doc.at_xpath('//*[local-name()="Body"]')
    
    operation_node = body&.at_xpath(".//*[local-name()='#{operation}']")
    return {} unless operation_node
    
    params = {}
    operation_node.children.each do |child|
      next if child.name == 'text' || child.text.strip.empty?
      
      key = child.name.to_sym
      value = child.text.strip
      
      # Convertir tipos básicos
      case key
      when :precio
        params[key] = value.to_f
      when :año
        params[key] = value.to_i
      else
        params[key] = value
      end
    end
    
    params
  end

  def handle_create_instrumento(doc)
    params = extract_params(doc, 'CreateInstrumento')
    result = @service.create_instrumento(params)
    soap_response('CreateInstrumentoResponse', result)
  end

  def handle_get_instrumento_by_id(doc)
    params = extract_params(doc, 'GetInstrumentoById')
    result = @service.get_instrumento_by_id(params[:id])
    soap_response('GetInstrumentoByIdResponse', result)
  end

  def handle_get_instrumentos_by_name(doc)
    params = extract_params(doc, 'GetInstrumentosByName')
    result = @service.get_instrumentos_by_name(params[:nombre])
    soap_response('GetInstrumentosByNameResponse', { instrumentos: result })
  end

  def handle_update_instrumento(doc)
    params = extract_params(doc, 'UpdateInstrumento')
    result = @service.update_instrumento(params)
    soap_response('UpdateInstrumentoResponse', result)
  end

  def handle_delete_instrumento(doc)
    params = extract_params(doc, 'DeleteInstrumento')
    result = @service.delete_instrumento(params[:id])
    soap_response('DeleteInstrumentoResponse', result)
  end

  def soap_response(operation, data)
    xml = Builder::XmlMarkup.new(indent: 2)
    xml.instruct!
    
    xml.tag!('soap:Envelope',
             'xmlns:soap' => 'http://schemas.xmlsoap.org/soap/envelope/',
             'xmlns:tns' => 'http://tempuri.org/') do
      xml.tag!('soap:Body') do
        xml.tag!("tns:#{operation}") do
          if data.is_a?(Array)
            data.each do |item|
              build_instrumento_xml(xml, item)
            end
          elsif data.is_a?(Hash) && data[:instrumentos]
            data[:instrumentos].each do |item|
              build_instrumento_xml(xml, item)
            end
          elsif data.is_a?(Hash)
            build_instrumento_xml(xml, data)
          end
        end
      end
    end
  end

  def build_instrumento_xml(xml, data)
    if data[:success]
      xml.success data[:success]
    else
      xml.instrumento do
        xml.id data[:id] if data[:id]
        xml.nombre data[:nombre] if data[:nombre]
        xml.marca data[:marca] if data[:marca]
        xml.precio data[:precio] if data[:precio]
        xml.modelo data[:modelo] if data[:modelo]
        xml.año data[:año] if data[:año]
        xml.linea data[:linea] if data[:linea]
      end
    end
  end

  def soap_fault(message)
    xml = Builder::XmlMarkup.new(indent: 2)
    xml.instruct!
    
    xml.tag!('soap:Envelope',
             'xmlns:soap' => 'http://schemas.xmlsoap.org/soap/envelope/') do
      xml.tag!('soap:Body') do
        xml.tag!('soap:Fault') do
          xml.faultcode 'Server'
          xml.faultstring message
        end
      end
    end
  end

  def generate_wsdl
    xml = Builder::XmlMarkup.new(indent: 2)
    xml.instruct!
    
    xml.definitions(
      'xmlns' => 'http://schemas.xmlsoap.org/wsdl/',
      'xmlns:tns' => 'http://tempuri.org/',
      'xmlns:soap' => 'http://schemas.xmlsoap.org/wsdl/soap/',
      'xmlns:xsd' => 'http://www.w3.org/2001/XMLSchema',
      'targetNamespace' => 'http://tempuri.org/'
    ) do
      
      # Types
      xml.types do
        xml.tag!('xsd:schema', 'targetNamespace' => 'http://tempuri.org/') do
          # Instrumento Type
          xml.tag!('xsd:complexType', 'name' => 'Instrumento') do
            xml.tag!('xsd:sequence') do
              xml.tag!('xsd:element', 'name' => 'id', 'type' => 'xsd:string')
              xml.tag!('xsd:element', 'name' => 'nombre', 'type' => 'xsd:string')
              xml.tag!('xsd:element', 'name' => 'marca', 'type' => 'xsd:string')
              xml.tag!('xsd:element', 'name' => 'precio', 'type' => 'xsd:double')
              xml.tag!('xsd:element', 'name' => 'modelo', 'type' => 'xsd:string')
              xml.tag!('xsd:element', 'name' => 'año', 'type' => 'xsd:int')
              xml.tag!('xsd:element', 'name' => 'linea', 'type' => 'xsd:string')
            end
          end
        end
      end

      # Messages
      xml.message('name' => 'CreateInstrumentoRequest') do
        xml.part('name' => 'parameters', 'element' => 'tns:CreateInstrumento')
      end
      
      xml.message('name' => 'CreateInstrumentoResponse') do
        xml.part('name' => 'parameters', 'element' => 'tns:CreateInstrumentoResponse')
      end

      # PortType
      xml.portType('name' => 'InstrumentoServicePortType') do
        xml.operation('name' => 'CreateInstrumento') do
          xml.input('message' => 'tns:CreateInstrumentoRequest')
          xml.output('message' => 'tns:CreateInstrumentoResponse')
        end
      end

      # Binding
      xml.binding('name' => 'InstrumentoServiceBinding', 'type' => 'tns:InstrumentoServicePortType') do
        xml.tag!('soap:binding', 'style' => 'document', 'transport' => 'http://schemas.xmlsoap.org/soap/http')
        
        xml.operation('name' => 'CreateInstrumento') do
          xml.tag!('soap:operation', 'soapAction' => 'CreateInstrumento')
          xml.input do
            xml.tag!('soap:body', 'use' => 'literal')
          end
          xml.output do
            xml.tag!('soap:body', 'use' => 'literal')
          end
        end
      end

      # Service
      xml.service('name' => 'InstrumentoService') do
        xml.port('name' => 'InstrumentoServicePort', 'binding' => 'tns:InstrumentoServiceBinding') do
          xml.tag!('soap:address', 'location' => "#{request.scheme}://#{request.host}:#{request.port}#{request.script_name}")
        end
      end
    end
  end
end