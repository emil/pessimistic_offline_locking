# -*- coding: utf-8 -*-
require 'bundler'
Bundler.setup

require 'minitest/autorun'
require 'mocha/setup'
require 'byebug'
require 'active_record'
require 'i18n'
require File.expand_path("../mocha_ext", __FILE__)
require File.expand_path("../rpm_stubs", __FILE__)

require 'active-record-extensions'

Exact::Logging.log_dir_path = File.expand_path('../../log',__FILE__)

require 'erb'
erb_file = File.read(File.dirname(__FILE__) + "/database.yml")
yaml_file = ERB.new(erb_file).result
ActiveRecord::Base.establish_connection(YAML.load(yaml_file)['test'])

class TestRecord < ActiveRecord::Base
  TYPE_MAPPINGS = Hash.new(ActiveRecord::Type::String.new).merge({
    string: ActiveRecord::Type::String.new,
    char: ActiveRecord::Type::String.new,
    text: ActiveRecord::Type::Text.new,
    clob: ActiveRecord::Type::Text.new,
    integer: ActiveRecord::Type::Integer.new,
    int: ActiveRecord::Type::Integer.new,
    decimal: ActiveRecord::Type::Decimal.new,
    float: ActiveRecord::Type::Float.new,
    double: ActiveRecord::Type::Float.new,
    boolean: ActiveRecord::Type::Boolean.new,
    date: ActiveRecord::Type::Date.new,
    time: ActiveRecord::Type::Time.new,
    datetime: ActiveRecord::Type::DateTime.new,
    timestamp: ActiveRecord::Type::DateTime.new,
    binary: ActiveRecord::Type::Binary.new,
    blob: ActiveRecord::Type::Binary.new,
  }).freeze unless defined?(TYPE_MAPPINGS)
  def self.columns() @form_fields ||= []; end
  def self.field_accessor(name, sql_type = nil, default = nil, null = true)
    columns << ActiveRecord::ConnectionAdapters::Column.new(name.to_s, default, TYPE_MAPPINGS[sql_type], null)
  end
  def _(str)
    "translated: #{str}"
  end
  def self._(str)
    "translated: #{str}"
  end
end

class MiniTest::Test

protected

  def rollback_db_transaction_when_complete
    ActiveRecord::Base.transaction do
      yield
      raise ActiveRecord::Rollback
    end
  end

  # For SSL extension tests
  #
  def testing_file_contents(file_name)
    IO.binread(File.join(File.dirname(__FILE__) + '/files/', file_name))
  end

  def generate_pem(not_before, not_after)
    key = OpenSSL::PKey::RSA.new(testing_file_contents('rsa_private_key.pem'))
    pub = key.public_key
    ca = OpenSSL::X509::Name.parse("/C=US/ST=Florida/L=Miami/O=Waitingf/OU=Poopstat/CN=waitingf.org/emailAddress=tester@testing.tst")
    cert = OpenSSL::X509::Certificate.new
    cert.version = 2
    cert.serial = 1
    cert.subject = ca
    cert.issuer = ca
    cert.public_key = pub
    cert.not_before = not_before
    cert.not_after = not_after
    root_ca, root_key = root_cert_key

    ef = OpenSSL::X509::ExtensionFactory.new
    ef.subject_certificate = cert
    ef.issuer_certificate = root_ca

    cert.add_extension(ef.create_extension("keyUsage","digitalSignature", true))
    cert.add_extension(ef.create_extension("subjectKeyIdentifier","hash",false))
    cert.sign(root_key, OpenSSL::Digest::SHA256.new)
    cert.to_pem
  end

  def expired_pem
    self.generate_pem(2.days.ago, 1.day.ago)
  end

  # Test CA. Certificate Issuing Authority that issues the above certs.
  def root_cert_key
    @root_cert_key ||= Proc.new {
      root_key = OpenSSL::PKey::RSA.new 2048 # the CA's public/private key
      root_ca = OpenSSL::X509::Certificate.new
      root_ca.version = 2 # cf. RFC 5280 - to make it a "v3" certificate
      root_ca.serial = 1
      root_ca.subject = OpenSSL::X509::Name.parse "/C=US/ST=Florida/L=Miami/O=Waitingf/OU=Poopstat/CN=Test Certification Authority/emailAddress=ca@test.com"
      root_ca.issuer = root_ca.subject # root CA's are "self-signed"
      root_ca.public_key = root_key.public_key
      root_ca.not_before = Time.now
      root_ca.not_after = root_ca.not_before + 2 * 365 * 24 * 60 * 60 # 2 years validity
      ef = OpenSSL::X509::ExtensionFactory.new
      ef.subject_certificate = root_ca
      ef.issuer_certificate = root_ca
      root_ca.add_extension(ef.create_extension("basicConstraints","CA:TRUE",true))
      root_ca.add_extension(ef.create_extension("keyUsage","keyCertSign, cRLSign", true))
      root_ca.add_extension(ef.create_extension("subjectKeyIdentifier","hash",false))
      root_ca.add_extension(ef.create_extension("authorityKeyIdentifier","keyid:always",false))
      root_ca.sign(root_key, OpenSSL::Digest::SHA256.new)
      [root_ca, root_key]
    }.call
  end

end
