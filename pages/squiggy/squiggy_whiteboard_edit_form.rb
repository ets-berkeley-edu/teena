module SquiggyWhiteboardEditForm

  include PageObject
  include Logging
  include Page
  include SquiggyPages

  text_field(:whiteboard_title_input, id: 'whiteboard-title-input')
  elements(:collaborator_name, :span, xpath: '//span[@class="v-chip__content"]')
  text_area(:collaborators_input, id: 'whiteboard-users-select')
  elements(:remove_collaborator_button, :button, xpath: '//span[@class="v-chip__content"]/button')
  div(:title_max_length_msg, xpath: '//div[text()="Title must be 255 characters or less"]')
  div(:no_collaborators_msg, xpath: 'TODO')

  def enter_whiteboard_title(title)
    enter_squiggy_text(whiteboard_title_input_element, title)
  end

  def collaborator_option_link(user)
    menu_option_el(user.full_name)
  end

  def collaborator_xpath(user)
    "//span[@class=\"v-chip__content\"][contains(text(), \"#{user.full_name}\")]"
  end

  def collaborator_name(user)
    span_element(xpath: collaborator_xpath(user))
  end

  def click_collaborators_input
    wait_for_update_and_click collaborators_input_element
  end

  def enter_whiteboard_collaborator(user)
    click_collaborators_input
    select_squiggy_option user.full_name
    collaborator_name(user).when_visible Utils.short_wait
  end

  def save_whiteboard
    wait_for_update_and_click save_button_element
  end

  def click_remove_collaborator(user)
    logger.debug "Clicking the remove button for #{user.full_name}"
    wait_for_update_and_click button_element(xpath: "#{collaborator_xpath(user)}/button")
    collaborator_name(user).when_not_present Utils.short_wait
  end

end
