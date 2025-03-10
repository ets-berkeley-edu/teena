require_relative '../util/spec_helper'

module Page

  class CalNetPage

    include PageObject
    include Logging
    include Page

    text_field(:username, id: 'username')
    text_field(:password, id: 'password')
    text_area(:sign_in_button, id: 'submitBtn')
    h3(:logout_conf_heading, xpath: '//h3[text()="Logout successful"]')
    h1(:duo_notice, xpath: '//h1[text()="Check for a Duo Push"]')
    button(:duo_trust_browser_button, id: 'trust-browser-button')
    span(:invalid_credentials, xpath: '//span[contains(text(), "invalid credentials")]')
    span(:access_denied_msg, xpath: '//span[contains(.,"Service access denied due to missing privileges.")]')

    def enter_credentials(username, password, msg=nil)
      # If no credentials are available, then wait for manual login
      wait_until(Utils.medium_wait) { title.include? 'CAS - CalNet Authentication Service Login' }
      if username == 'secret' || password == 'secret'
        if Utils.config['webdriver']['headless']
          logger.error 'Browser is running in headless mode, manual login is not supported'
          fail
        else
          logger.debug 'Waiting for manual login'
          prompt_for_action msg
          wait_for_manual_login
        end
      else
        logger.debug "#{username} is logging in"
        wait_for_element_and_type(username_element, username)
        wait_for_element_and_type(password_element, password)
        wait_for_update_and_click sign_in_button_element
        wait_until(Utils.long_wait) do
          duo_trust_browser_button? ||
            invalid_credentials? ||
            (!title.include?('CalNet Authentication Service') && !current_url.include?('duosecurity')) ||
            logout_conf_heading_element.visible?
        end
        if duo_trust_browser_button?
          duo_trust_browser_button
        elsif invalid_credentials?
          fail('Invalid credentials')
        end
      end
    end

    def prompt_for_action(msg)
      wait_for_element_and_type(username_element, msg)
    end

    def wait_for_manual_login(custom_wait=nil)
      wait_until(custom_wait || Utils.long_wait) do
        # If login is to resolve a Junction session conflict, then logout should occur. Otherwise, expect successful login.
        logout_conf_heading_element.visible? ||
          (!title.include?('Central Authentication Service') && !current_url.include?('duosecurity'))
      end
    end

    def log_in(username, password, msg = 'PLEASE LOG IN MANUALLY')
      enter_credentials(username, password, msg)
      wait_for_manual_login
    end

    # Hits the CAS logout URL directly
    def log_out
      navigate_to "#{Utils.cal_net_url}/cas/logout"
      logout_conf_heading_element.when_visible Utils.medium_wait
      sleep 1
    end

  end
end
