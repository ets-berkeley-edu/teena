require_relative '../../util/spec_helper'

if (ENV['DEPS'] || ENV['DEPS'].nil?) && !ENV['NO_DEPS']

  describe 'A BOA advisor' do

    include Logging

    before(:all) do
      @test = BOACTestConfig.new
      @test.user_role_advisor

      @test_asc = BOACTestConfig.new
      @test_asc.user_role_asc @test

      @test_coe = BOACTestConfig.new
      @test_coe.user_role_coe @test

      @admin_cohorts = BOACUtils.get_everyone_filtered_cohorts({default: true}, BOACDepartments::ADMIN)
      @admin_groups = BOACUtils.get_everyone_curated_groups BOACDepartments::ADMIN

      @driver = Utils.launch_browser @test.chrome_profile
      @homepage = BOACHomePage.new @driver
      @student_page = BOACStudentPage.new @driver
      @api_student_page = BOACApiStudentPage.new @driver
      @admit_page = BOACAdmitPage.new @driver
      @cohort_page = BOACFilteredCohortPage.new(@driver, @test_asc.advisor)
      @group_page = BOACGroupPage.new @driver
      @search_results_page = BOACSearchResultsPage.new @driver
      @settings_page = BOACFlightDeckPage.new @driver
      @api_admin_page = BOACApiAdminPage.new @driver

      # Get ASC test data
      filter = CohortFilter.new
      filter.set_custom_filters asc_inactive: true
      asc_sids = NessieFilterUtils.get_cohort_result(@test_asc, filter)
      @asc_test_student = @test.students.find { |s| s.sis_id == asc_sids.first }
      @homepage.dev_auth @test_asc.advisor
      api_page = BOACApiStudentPage.new @driver
      api_page.get_data(@driver, @asc_test_student)
      @asc_test_student_sports = api_page.asc_teams
      @homepage.load_page
      @homepage.log_out

      # Get CoE test data
      filter = CohortFilter.new
      filter.set_custom_filters coe_inactive: true
      coe_sids = NessieFilterUtils.get_cohort_result(@test_coe, filter)
      @coe_test_student = @test.students.find { |s| s.sis_id == coe_sids.first }

      # Get L&S test data
      @test_l_and_s = BOACTestConfig.new
      @test_l_and_s.user_role_l_and_s @test
      @l_and_s_cohorts = BOACUtils.get_everyone_filtered_cohorts({default: true}, BOACDepartments::L_AND_S)
      @l_and_s_groups = BOACUtils.get_everyone_curated_groups BOACDepartments::L_AND_S

      # Get admit data
      admits = NessieUtils.get_admits
      no_sir = admits.select { |a| !a.is_sir }
      @admit = if no_sir.any?
                 no_sir.last
               else
                 admits.last
               end
      logger.debug "The test admit's SID is #{@admit.sis_id}"
      ce3_advisor = BOACUtils.get_dept_advisors(BOACDepartments::ZCEEE, DeptMembership.new(advisor_role: AdvisorRole::ADVISOR)).first
      ce3_cohort_search = CohortAdmitFilter.new
      ce3_cohort_search.set_custom_filters urem: true
      @ce3_cohort = FilteredCohort.new search_criteria: ce3_cohort_search, name: "CE3 #{@test.id}"
      @homepage.dev_auth ce3_advisor
      @cohort_page.search_and_create_new_cohort(@ce3_cohort, admits: true)
      @cohort_page.log_out
    end

    after(:all) { Utils.quit_browser @driver }

    context 'with ASC' do

      before(:all) { @homepage.dev_auth @test_asc.advisor }

      after(:all) do
        @homepage.load_page
        @homepage.log_out
      end

      context 'visiting Everyone\'s Cohorts' do

        it 'sees only filtered cohorts created by ASC advisors' do
          expected = BOACUtils.get_everyone_filtered_cohorts({default: true}, BOACDepartments::ASC).map(&:id).sort
          visible = (@cohort_page.visible_everyone_cohorts.map &:id).sort
          @cohort_page.wait_until(1, "Missing: #{expected - visible}. Unexpected: #{visible - expected}") { visible == expected }
        end

        it 'cannot hit an admin filtered cohort URL' do
          @admin_cohorts.any? ?
              @cohort_page.hit_non_auth_cohort(@admin_cohorts.first) :
              logger.warn('Skipping test for ASC access to admin cohorts because admins have no cohorts.')
        end

        it 'cannot hit a non-ASC filtered cohort URL' do
          coe_everyone_cohorts = BOACUtils.get_everyone_filtered_cohorts({default: true}, BOACDepartments::COE)
          coe_everyone_cohorts.any? ?
              @cohort_page.hit_non_auth_cohort(coe_everyone_cohorts.first) :
              logger.warn('Skipping test for ASC access to CoE cohorts because CoE has no cohorts.')
        end

        it('cannot hit a filtered admit cohort URL') { @cohort_page.hit_non_auth_cohort @ce3_cohort }
      end

      context 'visiting Everyone\'s Groups' do

        it 'sees only curated groups created by ASC advisors' do
          expected = BOACUtils.get_everyone_curated_groups(BOACDepartments::ASC).map(&:id).sort
          visible = (@group_page.visible_everyone_groups.map &:id).sort
          @group_page.wait_until(1, "Missing: #{expected - visible}. Unexpected: #{visible - expected}") { visible == expected }
        end

        it 'cannot hit an admin curated group URL' do
          @admin_groups.any? ?
              @group_page.hit_non_auth_group(@admin_groups.first) :
              logger.warn('Skipping test for ASC access to admin curated groups because admins have no groups.')
        end

        it 'cannot hit a non-ASC curated group URL' do
          coe_everyone_groups = BOACUtils.get_everyone_curated_groups BOACDepartments::COE
          coe_everyone_groups.any? ?
              @group_page.hit_non_auth_group(coe_everyone_groups.first) :
              logger.warn('Skipping test for ASC access to CoE curated groups because CoE has no groups.')
        end
      end

      context 'visiting a student page' do

        it 'sees team information' do
          @student_page.load_page @asc_test_student
          expect(@student_page.sports.sort).to eql(@asc_test_student_sports.sort)
        end

        it('sees ASC Inactive information') { expect(@student_page.inactive_asc_flag?).to be true }

        it 'sees no COE Inactive information' do
          @student_page.load_page @coe_test_student
          expect(@student_page.inactive_coe_flag?).to be false
        end
      end

      context 'visiting a student API page' do

        it 'cannot see COE profile data' do
          api_page = BOACApiStudentPage.new @driver
          api_page.get_data(@driver, @coe_test_student)
          api_page.coe_profile.each_value { |v| expect(v).to be_nil }
        end
      end

      context 'hitting an admit page' do

        it 'sees a 404' do
          @admit_page.hit_page_url @admit.sis_id
          @admit_page.wait_for_title 'Page not found'
        end
      end

      context 'hitting an admit endpoint' do

        it 'sees no data' do
          if @admit
            api_page = BOACApiAdmitPage.new @driver
            api_page.hit_endpoint @admit
            expect(api_page.message).to eql('Unauthorized')
          else
            skip
          end
        end
      end

      context 'visiting a cohort page' do

        before(:all) do
          @inactive_search = CohortFilter.new
          @inactive_search.set_custom_filters({:asc_inactive => true})
          @inactive_cohort = FilteredCohort.new({:search_criteria => @inactive_search})

          @homepage.load_page
          @homepage.click_sidebar_create_filtered
          @opts = @cohort_page.filter_options
        end

        it('sees a College filter') { expect(@opts).to include('College') }
        it('sees an Entering Term filter') { expect(@opts).to include('Entering Term') }
        it('sees an EPN Grading Option filter') { expect(@opts).to include('EPN/CPN Grading Option') }
        it('sees an Expected Graduation Term filter') { expect(@opts).to include('Expected Graduation Term') }
        it('sees a GPA (Cumulative) filter') { expect(@opts).to include('GPA (Cumulative)') }
        it('sees a GPA (Last Term) filter') { expect(@opts).to include('GPA (Last Term)') }
        it('sees a Level filter') { expect(@opts).to include('Level') }
        it('sees a Major filter') { expect(@opts).to include('Major') }
        it('sees a Midpoint Deficient Grade filter') { expect(@opts).to include('Midpoint Deficient Grade') }
        it('sees a Transfer Student filter') { expect(@opts).to include 'Transfer Student' }
        it('sees a Units Completed filter') { expect(@opts).to include 'Units Completed' }

        it('sees an Ethnicity filter') { expect(@opts).to include('Ethnicity') }
        it('sees a Gender filter') { expect(@opts).to include('Gender') }
        it('sees an Underrepresented Minority filter') { expect(@opts).to include('Underrepresented Minority') }
        it('sees a Visa Type filter') { expect(@opts).to include('Visa Type') }

        it('sees an Inactive (ASC) filter') { expect(@opts).to include('Inactive (ASC)') }
        it('sees an Intensive (ASC) filter') { expect(@opts).to include('Intensive (ASC)') }
        it('sees a Team (ASC) filter') { expect(@opts).to include('Team (ASC)') }

        it('sees no Advisor (COE) filter') { expect(@opts).not_to include('Advisor (COE)') }
        it('sees no Ethnicity (COE) filter') { expect(@opts).not_to include('Ethnicity (COE)') }
        it('sees no Gender (COE) filter') { expect(@opts).not_to include('Gender (COE)') }
        it('sees no Inactive (COE) filter') { expect(@opts).not_to include('Inactive (COE)') }
        it('sees a Last Name filter') { expect(@opts).to include('Last Name') }
        it('sees a My Curated Groups filter') { expect(@opts).to include('My Curated Groups') }
        it('sees a My Students filter') { expect(@opts).to include('My Students') }
        it('sees no PREP (COE) filter') { expect(@opts).not_to include('PREP (COE)') }
        it('sees no Probation (COE) filter') { expect(@opts).not_to include('Probation (COE)') }
        it('sees no Underrepresented Minority (COE) filter') { expect(@opts).not_to include('Underrepresented Minority (COE)') }

        context 'with results' do

          before(:all) do
            @homepage.load_page
            @homepage.click_sidebar_create_filtered
            @cohort_page.perform_student_search @inactive_cohort
          end

          it('sees team information') do
            visible_sports = @cohort_page.student_sports(@asc_test_student).sort
            expect(visible_sports).to eql(@asc_test_student_sports.sort)
          end
          it('sees ASC Inactive information') { expect(@cohort_page.student_inactive_asc_flag? @asc_test_student).to be true }
        end
      end

      context 'performing a search' do

        it 'sees no Admits option' do
          @homepage.expand_search_options
          expect(@homepage.include_admits_cbx?).to be false
        end

        it 'sees no admit results' do
          if @admit.is_sir
            logger.warn 'Skipping admit search test since all admits have SIR'
          else
            @homepage.enter_string_and_hit_enter @admit.sis_id
            @search_results_page.no_results_msg.when_visible Utils.short_wait
          end
        end
      end

      context 'looking for admin functions' do

        before(:all) do
          @homepage.load_page
          @homepage.click_header_dropdown
        end

        it('can access the settings page') { expect(@homepage.settings_link?).to be true }
        it('cannot access the degree check page') { expect(@homepage.degree_checks_link?).to be false }
        it('cannot access the flight deck page') { expect(@homepage.flight_deck_link?).to be false }
        it('cannot access the passenger manifest page') { expect(@homepage.pax_manifest_link?).to be false }

        it 'can toggle demo mode' do
          @settings_page.load_advisor_page
          @settings_page.my_profile_heading_element.when_visible Utils.short_wait
          expect(@settings_page.demo_mode_toggle?).to be true
        end

        it('cannot post status alerts') { expect(@settings_page.status_heading?).to be false }

        it 'cannot hit the cachejob page' do
          @api_admin_page.load_cachejob
          @api_admin_page.unauth_msg_element.when_visible Utils.medium_wait
        end
      end
    end

    context 'with CoE' do

      before(:all) { @homepage.dev_auth @test_coe.advisor }

      after(:all) do
        @homepage.load_page
        @homepage.log_out
      end

      context 'visiting Everyone\'s Cohorts' do

        it 'sees only filtered cohorts created by CoE advisors' do
          expected = BOACUtils.get_everyone_filtered_cohorts({default: true}, BOACDepartments::COE).map(&:id).sort
          visible = (@cohort_page.visible_everyone_cohorts.map &:id).sort
          @cohort_page.wait_until(1, "Missing: #{expected - visible}. Unexpected: #{visible - expected}") { visible == expected }
        end

        it 'cannot hit an admin filtered cohort URL' do
          @admin_cohorts.any? ?
              @cohort_page.hit_non_auth_cohort(@admin_cohorts.first) :
              logger.warn('Skipping test for ASC access to admin cohorts because admins have no cohorts.')
        end

        it 'cannot hit a non-COE filtered cohort URL' do
          asc_cohorts = BOACUtils.get_everyone_filtered_cohorts({default: true}, BOACDepartments::ASC)
          asc_cohorts.any? ?
              @cohort_page.hit_non_auth_cohort(asc_cohorts.first) :
              logger.warn('Skipping test for COE access to ASC cohorts because ASC has no cohorts.')
        end

        it('cannot hit a filtered admit cohort URL') { @cohort_page.hit_non_auth_cohort @ce3_cohort }

      end

      context 'visiting Everyone\'s Groups' do

        it 'sees only curated groups created by CoE advisors' do
          expected = BOACUtils.get_everyone_curated_groups(BOACDepartments::COE).map(&:id).sort
          visible = (@group_page.visible_everyone_groups.map &:id).sort
          @group_page.wait_until(1, "Missing: #{expected - visible}. Unexpected: #{visible - expected}") { visible == expected }
        end

        it 'cannot hit an admin curated group URL' do
          @admin_groups.any? ?
              @group_page.hit_non_auth_group(@admin_groups.first) :
              logger.warn('Skipping test for ASC access to admin curated groups because admins have no groups.')
        end

        it 'cannot hit a non-COE curated group URL' do
          asc_groups = BOACUtils.get_everyone_curated_groups BOACDepartments::ASC
          asc_groups.any? ?
              @group_page.hit_non_auth_group(asc_groups.first) :
              logger.warn('Skipping test for COE access to ASC curated groups because ASC has no groups.')
        end
      end

      context 'visiting a COE student page' do

        before(:all) { @student_page.load_page @coe_test_student }

        it('sees COE Inactive information') { expect(@student_page.inactive_coe_flag?).to be true }
      end

      context 'visiting an ASC student page' do

        before(:all) { @student_page.load_page @asc_test_student }

        it('sees team information') { expect(@student_page.sports.sort).to eql(@asc_test_student_sports.sort) }
        it('sees no ASC Inactive information') { expect(@student_page.inactive_asc_flag?).to be false }
      end

      context 'hitting an admit page' do

        it 'sees a 404' do
          @admit_page.hit_page_url @admit.sis_id
          @admit_page.wait_for_title 'Page not found'
        end
      end

      context 'hitting an admit endpoint' do

        it 'sees no data' do
          if @admit
            api_page = BOACApiAdmitPage.new @driver
            api_page.hit_endpoint @admit
            expect(api_page.message).to eql('Unauthorized')
          else
            skip
          end
        end
      end

      context 'visiting a cohort page' do

        before(:all) do
          @inactive_search = CohortFilter.new
          @inactive_search.set_custom_filters({:asc_inactive => true})
          @inactive_cohort = FilteredCohort.new({:search_criteria => @inactive_search})

          @homepage.load_page
          @homepage.click_sidebar_create_filtered
          @opts = @cohort_page.filter_options
        end

        it('sees a College filter') { expect(@opts).to include('College') }
        it('sees an Entering Term filter') { expect(@opts).to include('Entering Term') }
        it('sees an EPN Grading Option filter') { expect(@opts).to include('EPN/CPN Grading Option') }
        it('sees an Expected Graduation Term filter') { expect(@opts).to include('Expected Graduation Term') }
        it('sees a GPA (Cumulative) filter') { expect(@opts).to include('GPA (Cumulative)') }
        it('sees a GPA (Last Term) filter') { expect(@opts).to include('GPA (Last Term)') }
        it('sees a Level filter') { expect(@opts).to include('Level') }
        it('sees a Major filter') { expect(@opts).to include('Major') }
        it('sees a Midpoint Deficient Grade filter') { expect(@opts).to include('Midpoint Deficient Grade') }
        it('sees a Transfer Student filter') { expect(@opts).to include 'Transfer Student' }
        it('sees a Units Completed filter') { expect(@opts).to include 'Units Completed' }

        it('sees an Ethnicity filter') { expect(@opts).to include('Ethnicity') }
        it('sees a Gender filter') { expect(@opts).to include('Gender') }
        it('sees an Underrepresented Minority filter') { expect(@opts).to include('Underrepresented Minority') }
        it('sees a Visa Type filter') { expect(@opts).to include('Visa Type') }

        it('sees no Inactive ASC filter') { expect(@opts).not_to include('Inactive (ASC)') }
        it('sees no Intensive (ASC) filter') { expect(@opts).not_to include('Intensive (ASC)') }
        it('sees no Team (ASC) filter') { expect(@opts).not_to include('Team (ASC)') }

        it('sees an Advisor (COE) filter') { expect(@opts).to include('Advisor (COE)') }
        it('sees an Ethnicity (COE) filter') { expect(@opts).to include('Ethnicity (COE)') }
        it('sees a Gender (COE) filter') { expect(@opts).to include('Gender (COE)') }
        it('sees an Inactive (COE) filter') { expect(@opts).to include('Inactive (COE)') }
        it('sees a Last Name filter') { expect(@opts).to include('Last Name') }
        it('sees a My Curated Groups filter') { expect(@opts).to include('My Curated Groups') }
        it('sees a My Students filter') { expect(@opts).to include('My Students') }
        it('sees a PREP (COE) filter') { expect(@opts).to include('PREP (COE)') }
        it('sees a Probation (COE) filter') { expect(@opts).to include('Probation (COE)') }
        it('sees an Underrepresented Minority (COE) filter') { expect(@opts).to include('Underrepresented Minority (COE)') }

      end

      context 'performing a search' do

        it 'sees no Admits option' do
          @homepage.expand_search_options
          expect(@homepage.include_admits_cbx?).to be false
        end

        it 'sees no admit results' do
          if @admit.is_sir
            logger.warn 'Skipping admit search test since all admits have SIR'
          else
            @homepage.enter_string_and_hit_enter @admit.sis_id
            @search_results_page.no_results_msg.when_visible Utils.short_wait
          end
        end
      end

      context 'looking for admin functions' do

        before(:all) do
          @homepage.load_page
          @homepage.click_header_dropdown
        end

        it('can access the settings page') { expect(@homepage.settings_link?).to be true }
        it('can access the degree check page') { expect(@homepage.degree_checks_link?).to be true }
        it('cannot access the flight deck page') { expect(@homepage.flight_deck_link?).to be false }
        it('cannot access the passenger manifest page') { expect(@homepage.pax_manifest_link?).to be false }

        it 'can toggle demo mode' do
          @settings_page.load_advisor_page
          @settings_page.my_profile_heading_element.when_visible Utils.short_wait
          expect(@settings_page.demo_mode_toggle?).to be true
        end

        it('cannot post status alerts') { expect(@settings_page.status_heading?).to be false }

        it 'cannot hit the cachejob page' do
          @api_admin_page.load_cachejob
          @api_admin_page.unauth_msg_element.when_visible Utils.medium_wait
        end
      end
    end

    context 'with a department other than ASC or COE' do

      before(:all) { @homepage.dev_auth @test_l_and_s.advisor }

      after(:all) do
        @homepage.load_page
        @homepage.log_out
      end

      context 'visiting Everyone\'s Cohorts' do

        it 'sees only filtered cohorts created by advisors in its own department' do
          expected = @l_and_s_cohorts.map(&:id).sort
          visible = (@cohort_page.visible_everyone_cohorts.map &:id).sort
          @cohort_page.wait_until(1, "Missing: #{expected - visible}. Unexpected: #{visible - expected}") { visible == expected }
        end

        it 'cannot hit an admin filtered cohort URL' do
          @admin_cohorts.any? ?
              @cohort_page.hit_non_auth_cohort(@admin_cohorts.first) :
              logger.warn('Skipping test for ASC access to admin cohorts because admins have no cohorts.')
        end

        it('cannot hit a filtered admit cohort URL') { @cohort_page.hit_non_auth_cohort @ce3_cohort }
      end

      context 'visiting another user\'s cohort' do

        before(:all) { @cohort_page.load_cohort @l_and_s_cohorts.find { |c| ![@test_l_and_s.advisor.uid, '70143'].include? c.owner_uid } }

        it('can view the filters') { @cohort_page.show_filters }
        it('cannot edit the filters') { expect(@cohort_page.cohort_edit_button_elements).to be_empty }
        it('can export the student list') { expect(@cohort_page.export_list_button?).to be true }
        it('cannot rename the cohort') { expect(@cohort_page.rename_cohort_button?).to be false }
        it('cannot delete the cohort') { expect(@cohort_page.delete_cohort_button?).to be false }
      end

      context 'visiting Everyone\'s Groups' do

        it 'sees only curated groups created by advisors in its own department' do
          expected = @l_and_s_groups.map(&:id).sort
          visible = (@group_page.visible_everyone_groups.map &:id).sort
          @group_page.wait_until(1, "Missing: #{expected - visible}. Unexpected: #{visible - expected}") { visible == expected }
        end

        it 'cannot hit an admin curated group URL' do
          @admin_groups.any? ?
              @group_page.hit_non_auth_group(@admin_groups.first) :
              logger.warn('Skipping test for ASC access to admin curated groups because admins have no groups.')
        end
      end

      context 'visiting another user\'s curated group' do

        before(:all) { @group_page.load_page @l_and_s_groups.find { |g| g.owner_uid != @test_l_and_s.advisor.uid } }

        it('can export the student list') { expect(@group_page.export_list_button?).to be true }
        it('cannot add students') { expect(@group_page.add_students_button?).to be false }
        it('cannot rename the cohort') { expect(@group_page.rename_cohort_button?).to be false }
        it('cannot delete the cohort') { expect(@group_page.delete_cohort_button?).to be false }
      end

      context 'visiting an ASC student page' do

        before(:all) { @student_page.load_page @asc_test_student }

        it('sees team information') { expect(@student_page.sports.sort).to eql(@asc_test_student_sports.sort) }
        it('sees no ASC Inactive information') { expect(@student_page.inactive_asc_flag?).to be false }
      end

      context 'visiting a COE student page' do

        before(:all) { @student_page.load_page @coe_test_student }

        it('sees no COE Inactive information') { expect(@student_page.inactive_coe_flag?).to be false }
      end

      context 'visiting a student API page' do

        it 'cannot see COE profile data on the student API page' do
          api_page = BOACApiStudentPage.new @driver
          api_page.get_data(@driver, @coe_test_student)
          api_page.coe_profile.each_value { |v| expect(v).to be_nil }
        end
      end

      context 'hitting an admit page' do

        it 'sees a 404' do
          @admit_page.hit_page_url @admit.sis_id
          @admit_page.wait_for_title 'Page not found'
        end
      end

      context 'hitting an admit endpoint' do

        it 'sees no data' do
          if @admit
            api_page = BOACApiAdmitPage.new @driver
            api_page.hit_endpoint @admit
            expect(api_page.message).to eql('Unauthorized')
          else
            skip
          end
        end
      end

      context 'performing a filtered cohort search' do

        before(:all) do
          @homepage.load_page
          @homepage.click_sidebar_create_filtered
          @opts = @cohort_page.filter_options
        end

        it('sees a College filter') { expect(@opts).to include('College') }
        it('sees an Entering Term filter') { expect(@opts).to include('Entering Term') }
        it('sees an EPN/CPN Grading Option filter') { expect(@opts).to include('EPN/CPN Grading Option') }
        it('sees an Expected Graduation Term filter') { expect(@opts).to include('Expected Graduation Term') }
        it('sees a GPA (Cumulative) filter') { expect(@opts).to include('GPA (Cumulative)') }
        it('sees a GPA (Last Term) filter') { expect(@opts).to include('GPA (Last Term)') }
        it('sees a Level filter') { expect(@opts).to include('Level') }
        it('sees a Major filter') { expect(@opts).to include('Major') }
        it('sees a Midpoint Deficient Grade filter') { expect(@opts).to include('Midpoint Deficient Grade') }
        it('sees a Transfer Student filter') { expect(@opts).to include 'Transfer Student' }
        it('sees a Units Completed filter') { expect(@opts).to include 'Units Completed' }

        it('sees an Ethnicity filter') { expect(@opts).to include('Ethnicity') }
        it('sees a Gender filter') { expect(@opts).to include('Gender') }
        it('sees an Underrepresented Minority filter') { expect(@opts).to include('Underrepresented Minority') }
        it('sees a Visa Type filter') { expect(@opts).to include('Visa Type') }

        it('sees no Inactive (ASC) filter') { expect(@opts).not_to include('Inactive (ASC)') }
        it('sees no Intensive (ASC) filter') { expect(@opts).not_to include('Intensive (ASC)') }
        it('sees no Team filter (ASC)') { expect(@opts).not_to include('Team (ASC)') }

        it('sees no Advisor (COE) filter') { expect(@opts).not_to include('Advisor (COE)') }
        it('sees no Ethnicity (COE) filter') { expect(@opts).not_to include('Ethnicity (COE)') }
        it('sees no Gender (COE) filter') { expect(@opts).not_to include('Gender (COE)') }
        it('sees no Inactive (COE) filter') { expect(@opts).not_to include('Inactive (COE)') }
        it('sees a Last Name filter') { expect(@opts).to include('Last Name') }
        it('sees a My Curated Groups filter') { expect(@opts).to include('My Curated Groups') }
        it('sees a My Students filter') { expect(@opts).to include('My Students') }
        it('sees no PREP (COE) filter') { expect(@opts).not_to include('PREP (COE)') }
        it('sees no Probation (COE) filter') { expect(@opts).not_to include('Probation (COE)') }
        it('sees no Underrepresented Minority (COE) filter') { expect(@opts).not_to include('Underrepresented Minority (COE)') }

      end

      context 'performing a search' do

        it 'sees no Admits option' do
          @homepage.expand_search_options
          expect(@homepage.include_admits_cbx?).to be false
        end

        it 'sees no admit results' do
          if @admit.is_sir
            logger.warn 'Skipping admit search test since all admits have SIR'
          else
            @homepage.enter_string_and_hit_enter @admit.sis_id
            @search_results_page.no_results_msg.when_visible Utils.short_wait
          end
        end
      end

      context 'looking for admin functions' do

        before(:all) do
          @homepage.load_page
          @homepage.click_header_dropdown
        end

        it('can access the settings page') { expect(@homepage.settings_link?).to be true }
        it('cannot access the degree check page') { expect(@homepage.degree_checks_link?).to be false }
        it('cannot access the flight deck page') { expect(@homepage.flight_deck_link?).to be false }
        it('cannot access the passenger manifest page') { expect(@homepage.pax_manifest_link?).to be false }

        it 'can toggle demo mode' do
          @settings_page.load_advisor_page
          @settings_page.my_profile_heading_element.when_visible Utils.short_wait
          expect(@settings_page.demo_mode_toggle?).to be true
        end

        it('cannot post status alerts') do
          @settings_page.load_advisor_page
          @settings_page.my_profile_heading_element.when_visible Utils.short_wait
          expect(@settings_page.status_heading?).to be false
        end

        it 'cannot hit the cachejob page' do
          @api_admin_page.load_cachejob
          @api_admin_page.unauth_msg_element.when_visible Utils.medium_wait
        end
      end
    end

    context 'with assigned students' do

      before(:all) do
        plan = '25000U'
        @test.advisor = NessieUtils.get_my_students_test_advisor plan
        my_students_filter = CohortFilter.new
        my_students_filter.set_custom_filters cohort_owner_academic_plans: [plan]
        @my_students_cohort = FilteredCohort.new(search_criteria: my_students_filter, name: "My Students cohort #{@test.id}")

        @homepage.dev_auth @test.advisor
      end

      it 'can perform a cohort search for My Students' do
        @homepage.click_sidebar_create_filtered
        @cohort_page.perform_student_search @my_students_cohort
        @cohort_page.set_cohort_members(@my_students_cohort, @test)
        expected = @my_students_cohort.members.map &:sis_id
        visible = @cohort_page.visible_sids
        @cohort_page.wait_until(1, "Missing: #{expected - visible}. Unexpected: #{visible - expected}") do
          visible.sort == expected.sort
        end
      end

      it 'can export a My Students cohort with default columns' do
        parsed_csv = @cohort_page.export_student_list @my_students_cohort
        @cohort_page.verify_student_list_default_export(@my_students_cohort.members, parsed_csv)
      end

      it 'can export a My Students cohort with custom columns' do
        parsed_csv = @cohort_page.export_custom_student_list @my_students_cohort
        @cohort_page.verify_student_list_custom_export(@my_students_cohort.members, parsed_csv)
      end

      it 'has a My Students cohort visible to others' do
        @cohort_page.create_new_cohort @my_students_cohort
        @cohort_page.log_out
        @homepage.dev_auth
        @cohort_page.load_cohort @my_students_cohort
        expected = @my_students_cohort.members.map &:sis_id
        visible = @cohort_page.visible_sids
        @cohort_page.wait_until(1, "Missing: #{expected - visible}. Unexpected: #{visible - expected}") do
          visible.sort == expected.sort
        end
      end

      it 'has a My Students cohort that can be exported with default columns by another user' do
        parsed_csv = @cohort_page.export_student_list @my_students_cohort
        @cohort_page.verify_student_list_default_export(@my_students_cohort.members, parsed_csv)
      end

      it 'has a My Students cohort that can be exported with custom columns by another user' do
        parsed_csv = @cohort_page.export_custom_student_list @my_students_cohort
        @cohort_page.verify_student_list_custom_export(@my_students_cohort.members, parsed_csv)
      end
    end
  end
end
