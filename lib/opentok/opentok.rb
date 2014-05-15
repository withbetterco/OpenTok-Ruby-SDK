require "opentok/constants"
require "opentok/session"
require "opentok/client"
require "opentok/token_generator"
require "opentok/archives"

require "resolv"

module OpenTok
  # Contains methods for creating OpenTok sessions, generating tokens, and working with archives.
  #
  # To create a new OpenTok object, call the OpenTok constructor with your OpenTok API key
  # and the API secret from the OpenTok dashboard (https://dashboard.tokbox.com). Do not
  # publicly share your API secret. You will use it with the OpenTok constructor (only on your web
  # server) to create OpenTok sessions.
  #
  # @attr_reader [String] api_secret @private The OpenTok API secret.
  # @attr_reader [String] api_key @private The OpenTok API key.
  class OpenTok

    include TokenGenerator
    generates_tokens({
      :api_key => ->(instance) { instance.api_key },
      :api_secret => ->(instance) { instance.api_secret }
    })

    # @private
    # don't want these to be mutable, may cause bugs related to inconsistency since these values are
    # cached in objects that this can create
    attr_reader :api_key, :api_secret, :api_url

    ##
    # Create a new OpenTok object.
    #
    # @param [String] api_key Your OpenTok API key. See the OpenTok dashboard
    #   (https://dashboard.tokbox.com).
    # @param [String] api_secret Your OpenTok API key.
    # @param [String] api_url Do not set this parameter. It is for internal use by TokBox.
    def initialize(api_key, api_secret , api_url = ::OpenTok::API_URL)
      @api_key = api_key.to_s()
      @api_secret = api_secret
      # TODO: do we really need a copy of this in the instance or should we overwrite the module
      # constant so that other objects can access the same copy?
      @api_url = api_url
    end

    # Creates a new OpenTok session and returns the session ID, which uniquely identifies
    # the session.
    #
    # For example, when using the OpenTok JavaScript library, use the session ID when calling the
    # OT.initSession()</a> method (to initialize an OpenTok session).
    #
    # OpenTok sessions do not expire. However, authentication tokens do expire (see the
    # generateToken() method). Also note that sessions cannot explicitly be destroyed.
    #
    # A session ID string can be up to 255 characters long.
    #
    # Calling this method results in an OpenTokException in the event of an error.
    # Check the error message for details.
    #
    # You can also create a session using the OpenTok REST API (see
    # http://www.tokbox.com/opentok/api/#session_id_production) or the OpenTok dashboard
    # (see https://dashboard.tokbox.com/projects).
    #
    # @param [Hash] options (Optional) This hash defines options for the session. It includes
    #   the following keys (each of which is optional):
    #
    #   * :p2p (Boolean) -- The session's streams will be transmitted directly between
    #     peers (true) or using the OpenTok Media Router (false). By default, sessions use
    #     the OpenTok Media Router.
    #     
    #     The OpenTok Media Router</a> provides benefits not available in peer-to-peer sessions.
    #     For example, the OpenTok Media Router can decrease bandwidth usage in multiparty sessions.
    #     Also, the OpenTok Media Router can improve the quality of the user experience through
    #     dynamic traffic shaping. For more information, see
    #     http://www.tokbox.com/blog/mantis-next-generation-cloud-technology-for-webrtc and
    #     http://www.tokbox.com/blog/quality-of-experience-and-traffic-shaping-the-next-step-with-mantis.
    #     
    #     For peer-to-peer sessions, the session will attempt to transmit streams directly
    #     between clients. If clients cannot connect due to firewall restrictions, the session uses
    #     the OpenTok TURN server to relay audio-video streams.
    #     
    #     You will be billed for streamed minutes if you use the OpenTok Media Router or if the
    #     peer-to-peer session uses the OpenTok TURN server to relay streams. For information on
    #     pricing, see the OpenTok pricing page (http://www.tokbox.com/pricing).
    #
    #   * :location (String) -- An IP address that the OpenTok servers will use to
    #     situate the session in its global network. If you do not set a location hint,
    #     the OpenTok servers will be based on the first client connecting to the session.
    #
    # @return [Session] The Session object. The session_id property of the object is the session ID.
    def create_session(opts={})

      valid_opts = [ "p2p", "location" ]
      opts.keep_if { |k, v| valid_opts.include? k.to_s  }

      params = opts.clone
      params["p2p.preference"] = params.delete(:p2p) ? "enabled" : "disabled"
      unless params[:location].nil?
        raise "location must be an IPv4 address" unless params[:location] =~ Resolv::IPv4::Regex
      end

      response = client.create_session(params)
      Session.new api_key, api_secret, response['sessions']['Session']['session_id'], opts
    end

    # An Archives object, which lets you work with OpenTok 2.0 archives.
    def archives
      @archives ||= Archives.new client
    end

    protected

    def client
      @client ||= Client.new api_key, api_secret, api_url
    end

  end
end