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
            if !records.empty?
              freeze_time = 12*60*60 # 12小時內無法填寫
              is_record = records[-1].created_at + freeze_time > Time.now() ? true : false
            end
            
            view 'index', engine: 'html.erb', locals: { user: user, records: records, account: user.url, is_record: is_record}
          end
        end
      end

      routing.on 'fomo-dic' do
        # GET /fomo-dic
        routing.is do
          routing.get do
            user = session[:watching]
            
            records = user.owned_records
            if !records.empty?
              freeze_time = 12*60*60 # 12小時內無法填寫
              is_record = records[-1].created_at + freeze_time > Time.now() ? true : false
            end

            view 'fomo-dic', engine: 'html.erb', locals: { account: user.url, is_record: is_record }
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
                if !records.empty?
                  freeze_time = 12*60*60 # 12小時內無法填寫
                  is_record = records[-1].created_at + freeze_time > Time.now() ? true : false
                end
                pre_or_post = preorpost_currentstartday.split("&")[0]
                date_start = Date.parse(preorpost_currentstartday.split("&")[1])
                if pre_or_post == 'pre'
                  date_start -= 7
                else
                  date_start += 7
                end
                date_end = date_start + 6
                date_start = date_start.strftime('%m/%d')
                date_end = date_end.strftime('%m/%d')

                view 'my-history', engine: 'html.erb', locals: { 
                  account: user.url, 
                  records: records, 
                  is_record: is_record, 
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
            if !records.empty?
              freeze_time = 12*60*60 # 12小時內無法填寫
              is_record = records[-1].created_at + freeze_time > Time.now() ? true : false
            end

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

            view 'my-history', engine: 'html.erb', locals: { 
              account: account, 
              records: records, 
              is_record: is_record, 
              date_start: date_start, 
              date_end: date_end }
          end
        end
      end

      # questionnaire - question 2
      routing.on 'my-history' do
        
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

      routing.on 'form_complete' do
        routing.is do
          # POST /form_complete/
          routing.post do
            user = session[:watching]
            if user != nil
              record = Database::RecordOrm.create(access_time: 0, owner_id: session[:watching].id, fill_time: routing.params["fill_time"])
              num = 7 #題數
              (1..num).each { |i| Database::AnswerOrm.create(recordbook_id: record.id, question_num: i, answer_content: routing.params["#{i}"])}
            end
            routing.redirect "form_complete/#{user.url}}"
          end
        end
        routing.on String do |account|
          # GET /form_complete/#{account}
          routing.get do
            view 'form_complete', engine: 'html.erb', locals: { account: session[:watching].url }
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
            record = Database::RecordOrm.where(id: record).first
            record.update(access_time: record.access_time+1)
            answers = record.owned_answers.map(&:answer_content)
            view 'form_record', engine: 'html.erb', locals: { user: user, record: record, answers: answers }
          end
        end
      end
    end
  end
end
