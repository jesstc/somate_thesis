# frozen_string_literal: true

require 'roda'
require 'html'
require 'yaml'
require 'date'

module SoMate
  # Web App
  class App < Roda
    plugin :render, engine: 'html.erb', views: 'app/views'
    plugin :assets, css: 'style.css', path: 'app/views/assets'
    plugin :public, root: 'app/views/public'
    plugin :halt
    
    route do |routing|
      routing.assets # load CSS
      routing.public

      # GET /
      routing.root do
        session[:watching] ||= []
        view 'home', engine: 'html.erb'
      end

      routing.on 'error' do
        routing.is do
          routing.get do
            view 'error', engine: 'html.erb'
          end
        end
      end

      routing.on 'index' do
        routing.is do
          # POST /index/
          routing.post do
            # load testing data
            if ENV['RACK_ENV'] == "development"
              SoMate::InitializeDatabase::Create.load
            end
            
            account = routing.params['account']
            user = Database::UserOrm.where(account: account).first
            routing.redirect "index/#{user.url}"
          end
        end
        routing.on String do |account|
          # GET /index/account
          routing.get do
            user = Database::UserOrm.where(url: account).first
            if user.nil?
              routing.redirect "/error"
              routing.halt 400
            end

            session[:watching] = user
            records = user.owned_records
            current_date = Time.now.strftime("%H").to_i <= 14 ? Date.today-1 : Date.today
            is_record = records[-1].record_date == current_date.strftime('%Y-%m-%d').to_s ? true : false

            # 算出一週的時間區間
            current_date = Date.today
            if current_date.strftime('%A') == "Sunday"
              current_date -= 1
            end
            start_of_week = current_date - current_date.wday + 1
            end_of_week = start_of_week + 6
            # Format the dates as MM/DD
            date_start = start_of_week.strftime('%m/%d')
            date_end = end_of_week.strftime('%m/%d')

            # get record and ans records
            week_records = Database::RecordOrm.where(Sequel.lit("record_date BETWEEN ? AND ?", start_of_week, end_of_week))
                                              .where(owner_id: user.id).all
                                              # binding.irb
            
            if week_records.length != 0
              week_records.each do |record|
                use_moment = Database::AnswerOrm.where(recordbook_id: record.id, question_num: 2).first
                use_activities = Database::AnswerOrm.where(recordbook_id: record.id, question_num: 3).first
                use_moment = use_moment.answer_content
                use_activities = use_activities.answer_content

                use_moment_arr = use_moment.split("&")
                use_activities_arr = use_activities.split("&")
                # binding.irb
              end
            end
            # binding.irb
            
            view 'index', engine: 'html.erb', locals: { 
              user: user, 
              records: records, 
              account: user.url, 
              date_start: date_start,
              date_end: date_end,
              is_record: is_record}
          end
        end
      end

      routing.on 'fomo-dic' do
        # GET /fomo-dic
        routing.is do
          routing.get do
            user = Database::UserOrm.where(url: session[:watching].url).first
            if user.nil?
              routing.redirect "/error"
              routing.halt 400
            end
            session[:watching] = user
            
            records = user.owned_records
            current_date = Time.now.strftime("%H").to_i <= 14 ? Date.today-1 : Date.today
            is_record = records[-1].record_date == current_date.strftime('%Y-%m-%d').to_s ? true : false

            countermeasures = Database::CountermeasureOrm.all

            view 'fomo-dic', engine: 'html.erb', locals: { account: user.url, is_record: is_record, countermeasures: countermeasures }
          end
        end
      end

      routing.on 'my-history' do 
        # routing.is do
          routing.on 'change-date' do
            routing.on String do |preorpost_currentstartday|
              # GET /my-history/change-date/#{preorpost_currentstartday}
              routing.get do
                user = session[:watching]

                records = user.owned_records
                current_date = Time.now.strftime("%H").to_i <= 14 ? Date.today-1 : Date.today
                is_record = records[-1].record_date == current_date.strftime('%Y-%m-%d').to_s ? true : false

                pre_or_post = preorpost_currentstartday.split("&")[0]
                start_of_week = Date.parse(preorpost_currentstartday.split("&")[1])
                if pre_or_post == 'pre'
                  start_of_week -= 7
                else
                  start_of_week += 7
                end
                end_of_week = start_of_week + 6
                date_start = start_of_week.strftime('%m/%d')
                date_end = end_of_week.strftime('%m/%d')

                # get the records from database
                week_records = Database::RecordOrm.where(record_date: start_of_week..end_of_week).all
                week_ans = []
                if week_records.length != 0
                  week_records.each do |record|
                    answersorm_use_time = Database::AnswerOrm.where(recordbook_id: record.id, question_num: 1).first
                    answersorm_emoji_score = Database::AnswerOrm.where(recordbook_id: record.id, question_num: 4).first

                    if !answersorm_use_time.nil? && !answersorm_emoji_score.nil?
                      answers_use_time = answersorm_use_time.answer_content
                      answers_emoji_score = answersorm_emoji_score.answer_content

                      # change weekday from eng to chinese
                      weekday_mapping = { 'Mon' => '一', 'Tue' => '二', 'Wed' => '三', 'Thu' => '四', 'Fri' => '五', 'Sat' => '六', 'Sun' => '日' }
                      answers_created_time = weekday_mapping[Time.parse(record.record_date).strftime("%a")]
                      record_date = Time.parse(record.record_date).strftime("%m/%d")

                      element = { key: record.id, value: [record_date, answers_created_time, answers_use_time, answers_emoji_score] }
                      week_ans.push(element)
                    end
                  end
                end

                view 'my-history', engine: 'html.erb', locals: { 
                  account: user.url, 
                  records: records, 
                  is_record: is_record, 
                  week_ans: week_ans,
                  date_start: date_start, 
                  date_end: date_end }
              end
            end
          end
        # end

        routing.on String do |account|
          # GET /my-history/#{account}
          routing.get do
            user = session[:watching]

            records = user.owned_records
            current_date = Time.now.strftime("%H").to_i <= 14 ? Date.today-1 : Date.today
            is_record = records[-1].record_date == current_date.strftime('%Y-%m-%d').to_s ? true : false

            # 算出一週的時間區間
            current_date = Date.today
            if current_date.strftime('%A') == "Sunday"
              current_date -= 1
            end
            start_of_week = current_date - current_date.wday + 1
            end_of_week = start_of_week + 6
            # Format the dates as MM/DD
            date_start = start_of_week.strftime('%m/%d')
            date_end = end_of_week.strftime('%m/%d')

            # get the records from database
            week_records = Database::RecordOrm.where(record_date: start_of_week..end_of_week).all
            week_ans = []
            if week_records.length != 0
              week_records.each do |record|
                answersorm_use_time = Database::AnswerOrm.where(recordbook_id: record.id, question_num: 1).first
                answersorm_emoji_score = Database::AnswerOrm.where(recordbook_id: record.id, question_num: 4).first

                if !answersorm_use_time.nil? && !answersorm_emoji_score.nil?
                  answers_use_time = answersorm_use_time.answer_content
                  answers_emoji_score = answersorm_emoji_score.answer_content

                  # change weekday from eng to chinese
                  weekday_mapping = { 'Mon' => '一', 'Tue' => '二', 'Wed' => '三', 'Thu' => '四', 'Fri' => '五', 'Sat' => '六', 'Sun' => '日' }
                  answers_created_time = weekday_mapping[Time.parse(record.record_date).strftime("%a")]
                  record_date = Time.parse(record.record_date).strftime("%m/%d")

                  element = { key: record.id, value: [record_date, answers_created_time, answers_use_time, answers_emoji_score] }
                  week_ans.push(element)
                end
              end
            end

            view 'my-history', engine: 'html.erb', locals: { 
              account: account, 
              records: records,
              is_record: is_record, 
              week_ans: week_ans,
              date_start: date_start, 
              date_end: date_end }
          end
        end
      end

      routing.on 'meditation' do
        routing.on String do |account|
          routing.get do
            user = session[:watching]
            view 'meditation', engine: 'html.erb', locals: { account: user.url }
          end
        end
      end

      # questionnaire - question 1
      routing.on 'form' do
        routing.on String do |account|
          # GET /form/#{account}
          routing.get do
            user = session[:watching]
            view 'form', engine: 'html.erb', locals: { account: user.url, user: user, fill_time: 0, q1_hours: 0, q1_mins: 0 }
          end
        end
      end

      # questionnaire - question 2
      routing.on 'form_2' do
        routing.on String do |account|
          # POST /form_2/#{account}
          routing.post do
            user = session[:watching]

            view 'form_2', engine: 'html.erb', locals: { account: user.url, user: user, fill_time: routing.params["fill_time"], q1_ans: routing.params["1"]}
          end
        end
      end

      # questionnaire - question 3
      routing.on 'form_3' do
        routing.on String do |account|
          # POST /form_3/#{account}
          routing.post do
            user = session[:watching]

            # Q2 ans string
            q2_ans = ""
            routing.params["q2_ans"].each_with_index do |ans, index|
              if index !=0
                q2_ans += "|"
              end
              q2_ans += ans
            end

            view 'form_3', engine: 'html.erb', locals: { 
              account: user.url, 
              user: user, 
              fill_time: routing.params["fill_time"], 
              q1_ans: routing.params["1"], 
              q2_ans: q2_ans
            }
          end
        end
      end

      # questionnaire - question 4
      routing.on 'form_4' do
        routing.on String do |account|
          # POST /form_4/#{account}
          routing.post do
            user = session[:watching]

            # Q2 ans string
            q3_ans = ""
            routing.params["q3_ans"].each_with_index do |ans, index|
              if index !=0
                q3_ans += "|"
              end
              q3_ans += ans
            end

            view 'form_4', engine: 'html.erb', locals: { 
              account: user.url, 
              user: user, 
              fill_time: routing.params["fill_time"], 
              q1_ans: routing.params["1"], 
              q2_ans: routing.params["2"], 
              q3_ans: q3_ans
            }
          end
        end
      end

      # questionnaire - question 5
      routing.on 'form_5' do
        routing.on String do |account|
          # POST /form_5/#{account}
          routing.post do
            user = session[:watching]

            view 'form_5', engine: 'html.erb', locals: { 
              account: user.url, 
              user: user, 
              fill_time: routing.params["fill_time"], 
              q1_ans: routing.params["1"], 
              q2_ans: routing.params["2"], 
              q3_ans: routing.params["3"],
              q4_ans: routing.params["4"]
            }
          end
        end
      end

      # questionnaire - question 6
      routing.on 'form_6' do
        routing.on String do |account|
          # POST /form_6/#{account}
          routing.post do
            user = session[:watching]

            view 'form_6', engine: 'html.erb', locals: { 
              account: user.url, 
              user: user, 
              fill_time: routing.params["fill_time"], 
              q1_ans: routing.params["1"], 
              q2_ans: routing.params["2"], 
              q3_ans: routing.params["3"],
              q4_ans: routing.params["4"],
              q5_ans: routing.params["5"]
            }
          end
        end
      end

      # questionnaire - question 7
      routing.on 'form_7' do
        routing.on String do |account|
          # POST /form_7/#{account}
          routing.post do
            user = session[:watching]

            view 'form_7', engine: 'html.erb', locals: { 
              account: user.url, 
              user: user, 
              fill_time: routing.params["fill_time"], 
              q1_ans: routing.params["1"], 
              q2_ans: routing.params["2"], 
              q3_ans: routing.params["3"],
              q4_ans: routing.params["4"],
              q5_ans: routing.params["5"],
              q6_ans: routing.params["6"]
            }
          end
        end
      end

      # questionnaire - question 8
      routing.on 'form_8' do
        routing.on String do |account|
          # POST /form_8/#{account}
          routing.post do
            user = session[:watching]

            view 'form_8', engine: 'html.erb', locals: { 
              account: user.url, 
              user: user, 
              fill_time: routing.params["fill_time"], 
              q1_ans: routing.params["1"], 
              q2_ans: routing.params["2"], 
              q3_ans: routing.params["3"],
              q4_ans: routing.params["4"],
              q5_ans: routing.params["5"],
              q6_ans: routing.params["6"],
              q7_ans: routing.params["7"]
            }
          end
        end
      end

      # questionnaire - question 9
      routing.on 'form_9' do
        routing.on String do |account|
          # POST /form_9/#{account}
          routing.post do
            user = session[:watching]

            view 'form_9', engine: 'html.erb', locals: { 
              account: user.url, 
              user: user, 
              fill_time: routing.params["fill_time"], 
              q1_ans: routing.params["1"], 
              q2_ans: routing.params["2"], 
              q3_ans: routing.params["3"],
              q4_ans: routing.params["4"],
              q5_ans: routing.params["5"],
              q6_ans: routing.params["6"],
              q7_ans: routing.params["7"],
              q8_ans: routing.params["8"]
            }
          end
        end
      end

      # countermeasure page after the form
      routing.on 'countermeasure_page' do
        routing.on String do |random_id|
          # GET /countermeasure_page/#{random_id}
          routing.get do
            user = session[:watching]
            countermeasure = Database::CountermeasureOrm.where(id: random_id).first

            view 'countermeasure_page', engine: 'html.erb', locals: { 
              account: user.url, 
              user: user, 
              countermeasure: countermeasure
            }
          end
        end
      end

      # to check if they practice the countermeasure and why
      routing.on 'countermeasure_record' do
        routing.is do
          # POST /countermeasure_record/
          routing.post do
            user = session[:watching]
            
            # add countermeasure record
            countermeasure_id = routing.params["countermeasure_id"]
            is_try = routing.params["is_try"] == 'true' ? true : false
            selected_content = routing.params["selected_content"]
            countermeasurerecord = Database::CountermeasureRecordOrm.create(countermeasure_id: countermeasure_id, owner_id: session[:watching].id, is_try: is_try, selected_content: selected_content)

            routing.redirect "form_complete/#{user.url}/countermeasure"
          end
        end

        routing.on String do |countermeasure_id|
          routing.on String do |countermeasure_status|
            # GET /countermeasure_record/#{countermeasure_id}/try_next
            # GET /countermeasure_record/#{countermeasure_id}/tried
            # try_nex or tried --> #{countermeasure_status}
            routing.get do
              user = session[:watching]

              if countermeasure_status == 'try_next'
                is_try = false;
              else 
                is_try = true;
              end

              view 'countermeasure_record', engine: 'html.erb', locals: { 
                account: user.url,
                is_try: is_try,
                countermeasure_id: countermeasure_id
              }
            end
          end
        end
      end

      routing.on 'form_complete' do
        routing.is do
          # POST /form_complete/
          routing.post do
            user = session[:watching]
            if user != nil
              # 確認該筆資料在統計圖表上要歸屬哪一天
              current_date = Date.today
              current_hour = Time.now.strftime("%H").to_i
              if current_hour <= 14
                current_date -= 1
              end
              record_date = current_date.strftime('%Y-%m-%d')

              record = Database::RecordOrm.create(access_time: 0, owner_id: session[:watching].id, fill_time: routing.params["fill_time"], record_date: record_date)
              num = routing.params["question_num"].to_i #題數
              (1..num).each { |i| Database::AnswerOrm.create(recordbook_id: record.id, question_num: i, answer_content: routing.params["#{i}"])}
            end

            if routing.params["not-sure-check"] == "checked"
              random_id = Date.today.yday % 10 + 1  
              routing.redirect "countermeasure_page/#{random_id}"
            else 
              routing.redirect "form_complete/#{user.url}"
            end
          end
        end
        routing.on String do |account|
          routing.on 'countermeasure' do
            routing.is do
              # GET /form_complete/#{account}/countermeasure
              routing.get do
                view 'form_complete', engine: 'html.erb', locals: { account: session[:watching].url, is_countermeasure: true }
              end
            end
          end

          # GET /form_complete/#{account}
          routing.get do
            view 'form_complete', engine: 'html.erb', locals: { account: session[:watching].url, is_countermeasure: false }
          end
        end
      end

      routing.on 'all_records' do
        routing.on String do |account|
          # GET /all_records/#{account}
          routing.get do
            user = session[:watching]
            records = user.owned_records
            view 'all_records', engine: 'html.erb', locals: { user: user, records: records, account: user.url }
          end
        end
      end

      routing.on 'form_record' do
        routing.on String do |record|
          # GET /form_record/#{record}
          routing.get do
            user = session[:watching]

            records = user.owned_records
            current_date = Time.now.strftime("%H").to_i <= 14 ? Date.today-1 : Date.today
            is_record = records[-1].record_date == current_date.strftime('%Y-%m-%d').to_s ? true : false

            record = Database::RecordOrm.where(id: record).first
            record.update(access_time: record.access_time+1)
            answers = record.owned_answers.map(&:answer_content)
            view 'form_record', engine: 'html.erb', locals: { user: user, record: record, is_record: is_record, answers: answers }
          end
        end
      end
    end
  end
end
