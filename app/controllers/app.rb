# frozen_string_literal: true

require 'roda'
require 'html'
require 'yaml'

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
