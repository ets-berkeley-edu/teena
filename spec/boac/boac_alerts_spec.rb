require_relative '../../util/spec_helper'

describe 'A BOAC alert' do

  include Logging

  begin

    @alert = BOACUtils.get_test_alert

    if @alert

      test = BOACTestConfig.new
      @driver = Utils.launch_browser test.chrome_profile
      logger.debug "Picking an advisor whose UID is not #{Utils.super_admin_uid}"
      @advisor = BOACUtils.get_admin_users.find { |u| u.uid.to_s != Utils.super_admin_uid.to_s }
      logger.debug "Advisor UID is #{@advisor.uid}"
      BOACUtils.remove_alert_dismissal(@alert) if BOACUtils.get_dismissed_alerts([@alert], @advisor).any?

      @homepage = BOACHomePage.new @driver
      @search_page = BOACSearchResultsPage.new @driver
      @student_page = BOACStudentPage.new @driver

      # View non-dismissed alert
      @homepage.dev_auth
      @search_page.search @alert.user.sis_id
      @search_page.click_student_result @alert.user
      alert_visible = @student_page.wait_until(Utils.short_wait) { @student_page.non_dismissed_alert_msgs.include? @alert.message }
      it('is shown by default on the student page when not dismissed') { expect(alert_visible).to be_truthy }

      # Dismiss alert
      @student_page.dismiss_alert @alert
      alert_dismissed = @student_page.wait_until(3) do
        !@student_page.non_dismissed_alert_ids.include? @alert.id
        @student_page.dismissed_alert_msgs.include? @alert.message
        !@student_page.dismissed_alert_msg_elements.any?(&:visible?)
      end
      it('is no longer shown by default when dismissed') { expect(alert_dismissed).to be_truthy }

      # Reveal dismissed alert
      @student_page.click_view_dismissed_alerts
      alert_revealed = @student_page.wait_until(1) { @student_page.dismissed_alert_msg_elements.all? &:visible? }
      it('can be revealed when dismissed') { expect(alert_revealed).to be_truthy }

      # Hide dismissed alert
      @student_page.click_hide_dismissed_alerts
      alert_hidden = @student_page.wait_until(1) { !@student_page.dismissed_alert_msg_elements.any?(&:visible?) }
      it('can be hidden when dismissed') { expect(alert_hidden).to be_truthy }

      # As another user, verify alert is not dismissed
      @student_page.log_out
      @homepage.dev_auth @advisor
      @search_page.search @alert.user.sis_id
      @search_page.click_student_result @alert.user
      alert_not_dismissed = @student_page.wait_until(Utils.short_wait) { @student_page.non_dismissed_alert_msgs.include? @alert.message }
      it('is not dismissed for other users when dismissed') { expect(alert_not_dismissed).to be_truthy }

    else

      it('is not present and cannot be tested') { fail }

    end

  rescue => e
    BOACUtils.log_error_and_screenshot(@driver, e, "#{@alert.user.uid}")
    it('encountered an unexpected error') { fail }
  ensure
    Utils.quit_browser @driver
  end
end
