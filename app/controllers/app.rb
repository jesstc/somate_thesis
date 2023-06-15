# frozen_string_literal: true

require 'roda'
require 'html'
require 'yaml'
require 'date'
require 'json'

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

      routing.on 'get-viz4-arr' do
        routing.is do
          # POST /get-viz4-arr/
          routing.post do
            # selected_bodypart = params[:selected_opt]
            selected_bodypart = routing.params['selected_bodypart']
            start_date = Date.strptime(routing.params['start_date'], "%m/%d")
            end_date = Date.strptime(routing.params['end_date'], "%m/%d")
            userid = routing.params['userid']

            # viz 4 data process
            current_week_records = Hash.new(0)
            week_records = Database::RecordOrm.where(Sequel.lit("record_date BETWEEN ? AND ?", start_date, end_date))
                                              .where(owner_id: userid).all
            if week_records.length != 0
              week_records.each do |record|
                happy_score = Database::AnswerOrm.where(recordbook_id: record.id, question_num: 4).first.answer_content
                use_emo_feel = Database::AnswerOrm.where(recordbook_id: record.id, question_num: 5).first.answer_content
                
                current_week_records[record.record_date] = {
                  happy_score: happy_score.to_i,
                  use_emo_feel: use_emo_feel.split("|")
                }
              end
            end

            # get the emotions and feelings and sort by bodyparts
            emo_feel_hash = Hash.new(0)
            emo_feel_arr = []
            current_week_records.each do |record_date, content|
              content[:use_emo_feel].each do |emo_feel|
                emo_feel_arr = emo_feel.split("&")

                if emo_feel_arr[1] == selected_bodypart
                  if emo_feel_hash[emo_feel_arr[1]] == 0
                    emo_feel_hash[emo_feel_arr[1]] = {}
                    emo_feel_hash[emo_feel_arr[1]][:happy_score] = [] 
                    emo_feel_hash[emo_feel_arr[1]][:emo_feel] = []
                  end
                  emo_feel_hash[emo_feel_arr[1]][:happy_score].push(content[:happy_score])
                  emo_feel_hash[emo_feel_arr[1]][:emo_feel].push([emo_feel_arr[0], emo_feel_arr[2]])
                end
              end
            end

            # 直接計算 happy score 的平均值
            if emo_feel_hash.length != 0
              happy_score_arr = emo_feel_hash[selected_bodypart][:happy_score]
              emo_feel_hash[selected_bodypart][:happy_score] = (happy_score_arr.reduce(0, :+) / happy_score_arr.size.to_f).round(1)
            end

            emo_feel_hash.to_json
          end
        end
      end

      routing.on 'index' do
        routing.is do
          # POST /index/
          routing.post do
            # load testing data
            SoMate::InitializeDatabase::Create.load
            
            account = routing.params['account']
            user = Database::UserOrm.where(account: account).first
            routing.redirect "index/#{user.url}/current"
          end
        end
        routing.on String do |account|
          routing.on String do |date|
            # GET /index/#{account}/#{date}
            routing.get do
              user = Database::UserOrm.where(url: account).first
              if user.nil?
                routing.redirect "/error"
                routing.halt 400
              end

              session[:watching] = user
              is_record = false
              current_date = Time.now.strftime("%H").to_i <= 14 ? Date.today-1 : Date.today
              records = user.owned_records
              if records.length != 0
                is_record = records[-1].record_date == current_date.strftime('%Y-%m-%d').to_s ? true : false
              end

              # promt text
              prompt_text = "你/妳今天還沒紀錄喔～ 點選「開始紀錄」來填寫吧！"
              if is_record
                prompt_text_arr = ["可以透過「FoMO 小百科」更了解 FoMO 喔～", "可以透過「我的歷史紀錄」查看自己使用社群媒體的狀況喔！"]
                q9_ans = ""
                user_records = Database::RecordOrm.where(owner_id: user.id).all
                user_records.each do |record|
                  q9_tmp_ans = Database::AnswerOrm.where(recordbook_id: record.id, question_num: 9).first
                  q9_tmp_ans = q9_tmp_ans.nil? ? "" : q9_tmp_ans.answer_content
                  if !q9_tmp_ans.empty? 
                    q9_ans = q9_tmp_ans
                  end
                end
                prompt_text_arr.push("當你/妳使用社群平台時感到低落時，你/妳可以試著：" + q9_ans) 
                prompt_text = "恭喜你/妳完成今天的紀錄！" + prompt_text_arr[rand(prompt_text_arr.length) - 1]
              end

              # 算出一週的時間區間
              current_date = date == "current" ? Date.today : Date.parse(date)
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
              use_moment_arr = []
              use_activities_arr = []
              current_week_records = Hash.new(0)
              if week_records.length != 0
                has_data = true
                week_records.each do |record|
                  use_time = Database::AnswerOrm.where(recordbook_id: record.id, question_num: 1).first.answer_content
                  use_moment = Database::AnswerOrm.where(recordbook_id: record.id, question_num: 2).first.answer_content
                  use_activities = Database::AnswerOrm.where(recordbook_id: record.id, question_num: 3).first.answer_content
                  happy_score = Database::AnswerOrm.where(recordbook_id: record.id, question_num: 4).first.answer_content
                  use_emo_feel = Database::AnswerOrm.where(recordbook_id: record.id, question_num: 5).first.answer_content
                  
                  # get all use_moment & use_activities for viz_2
                  use_moment.split("|").each { |moment| use_moment_arr.push(moment)}
                  use_activities.split("|").each { |activity| use_activities_arr.push(activity)}

                  current_week_records[record.record_date] = {
                    use_time: use_time.to_i,
                    use_moments: use_moment.split("|"),
                    use_activities: use_activities.split("|"),
                    happy_score: happy_score.to_i,
                    use_emo_feel: use_emo_feel.split("|"),
                    record_id: record.id
                  }
                end
              else
                has_data = false
              end
              
              # viz 1 data process
              week_happy_scores = []
              week_use_times = []
              record_ids = []
              weekdays = [start_of_week, start_of_week+1, start_of_week+2, start_of_week+3, start_of_week+4, start_of_week+5, end_of_week]
              weekdays.each_with_index do |date, index|
                # generate weekdays
                weekdays[index] = date.strftime('%m/%d')

                # generate week_use_times
                current_week_records_index = date.strftime('%Y-%m-%d')
                if current_week_records[current_week_records_index] != 0
                  week_use_times[index] = current_week_records[current_week_records_index][:use_time]
                  current_happy_score = current_week_records[current_week_records_index][:happy_score]
                  record_ids[index] = current_week_records[current_week_records_index][:record_id]
                else
                  week_use_times[index] = 0
                  current_happy_score = 0
                  record_ids[index] = 0
                end

                # generate week_happy_scores
                week_happy_scores[index] = current_happy_score
              end
              viz_1 = { data: {
                          labels: weekdays, 
                          datasets: [
                            {type: "line", yAxisID: "line-y-axis", label: "情緒", borderColor: "#484848", backgroundColor: "#484848", borderWidth: 3, data: week_happy_scores},
                            {type: "bar", yAxisID: "bar-y-axis", label: "使用時間 (mins)", backgroundColor: "#AACFD1", data: week_use_times}
                        ]},
                        record_ids: record_ids
                      }

              # viz 2 data process
              # count all activity in the current week and sort 
              activity_count = Hash.new(0)
              use_activities_arr.each { |activity| activity_count[activity] += 1 }
              activity_count = activity_count.sort_by { |key, value| -value }
              moment_count = Hash.new(0)
              use_moment_arr.each { |moment| moment_count[moment] += 1 }
              moment_count = moment_count.sort_by { |key, value| -value }
              # check max index (前三名)
              activity_max = 3
              moment_max = 3
              activity_count.each_with_index do |ele, index|
                if index == activity_max
                  previous_count = activity_count[index-1][1]
                  current_count = ele[1]
                  activity_max = previous_count == current_count ? index + 1 : activity_max
                end
              end
              moment_count.each_with_index do |ele, index|
                if index == moment_max
                  previous_count = moment_count[index-1][1]
                  current_count = ele[1]
                  moment_max = previous_count == current_count ? index + 1 : moment_max
                end
              end
              viz_2 = {activity_max: activity_max, activities: activity_count, moment_max: moment_max, moments: moment_count}

              # viz 3 data process
              all_activities = ["發佈限時動態", "發佈貼文", "發佈短片 (Reels)", "回覆或按讚朋友的訊息/限時動態/貼文/短片 (Reels)", 
                                "查看通知 (追蹤要求、貼文通知)", "瀏覽朋友的限時動態", "瀏覽朋友的短片 (Reels) 或貼文",
                                "瀏覽其他人（非朋友）的限時動態/連續短片/貼文", "購物"]
              activities_times = activity_count.to_h   # 這週在 IG 上所有有做過的事情 & 次數
              # 這週做的事情對應到的 happy_score
              activities_happyscore = {}
              current_week_records.each do |date, record|
                record[:use_activities].each do |activity|
                  if activities_happyscore[activity].nil?   # array 還沒有這個值
                    activities_happyscore[activity] = [record[:happy_score]]
                  else
                    activities_happyscore[activity].push(record[:happy_score])
                  end
                end
              end
              # 算 happy_score 的平均
              activities_happyscore.each do |activity, happy_scores|
                activities_happyscore[activity] = (happy_scores.reduce(0, :+) / happy_scores.size.to_f).round(1)
              end
              # 這週沒有做過的事情
              activities_havenot_done = []
              all_activities.each do |activity|
                if activities_times[activity].nil?
                  activities_havenot_done.push(activity)
                end
              end
              # 根據上面的資料取出 viz_3 要用到的資料
              label_activities = []
              count_times = []
              avg_happy_scores = []
              activities_times.each do |activity, count_time|
                label_activities.push(activity)
                count_times.push(count_time)
                avg_happy_scores.push(activities_happyscore[activity])
              end
              # 把太長的 activity 文字縮短
              shorten_text = {"發佈限時動態" => "發佈限動", "發佈短片 (Reels)" => "發佈短片", 
                              "回覆或按讚朋友的訊息/限時動態/貼文/短片 (Reels)" => "回覆或按讚朋友的訊息與動態",
                              "查看通知 (追蹤要求、貼文通知)" => "查看通知", "瀏覽朋友的限時動態" => "瀏覽朋友的限動", 
                              "瀏覽朋友的短片 (Reels) 或貼文" => "瀏覽朋友的短片或貼文", 
                              "瀏覽其他人（非朋友）的限時動態/連續短片/貼文" => "瀏覽其他人的限動/短片/貼文"}
              label_activities.each_with_index do |activity, index| 
                if !shorten_text[activity].nil?
                  label_activities[index] = shorten_text[activity] 
                end
              end
              activities_havenot_done.each_with_index do |activity, index| 
                if !shorten_text[activity].nil?
                  activities_havenot_done[index] = shorten_text[activity]
                end
              end
              viz_3 = { data: {
                          labels: label_activities, 
                          datasets: [
                            {type: "line", yAxisID: "line-y-axis", label: "平均情緒", borderColor: "#484848", backgroundColor: "#484848", borderWidth: 3, data: avg_happy_scores},
                            {type: "bar", yAxisID: "bar-y-axis", label: "做的次數 (天/週)", backgroundColor: "#AACFD1", data: count_times}
                        ]},
                        activities_havenot_done: activities_havenot_done
                      }

              # viz 4 data process
              # get the emotions and feelings and sort by bodyparts
              emo_feel_by_bodyparts = Hash.new(0)
              emo_feel_arr = []
              current_week_records.each do |record_date, content|
                content[:use_emo_feel].each do |emo_feel|
                  emo_feel_arr = emo_feel.split("&")

                  if emo_feel_by_bodyparts[emo_feel_arr[1]] == 0
                    emo_feel_by_bodyparts[emo_feel_arr[1]] = {}
                    emo_feel_by_bodyparts[emo_feel_arr[1]][:happy_score] = []
                    emo_feel_by_bodyparts[emo_feel_arr[1]][:emo_feel] = []
                  end

                  emo_feel_by_bodyparts[emo_feel_arr[1]][:happy_score].push(content[:happy_score])
                  emo_feel_by_bodyparts[emo_feel_arr[1]][:emo_feel].push([emo_feel_arr[0], emo_feel_arr[2]])
                end
              end

              # 直接計算 happy score 的平均值
              if emo_feel_by_bodyparts.length != 0
                emo_feel_by_bodyparts.each do |bodypart, happyscore_emofeel|
                  happy_score_arr = happyscore_emofeel[:happy_score]
                  happyscore_emofeel[:happy_score] = (happy_score_arr.reduce(0, :+) / happy_score_arr.size.to_f).round(1)
                end
              end
              viz_4 = {emofeel_by_bodyparts: emo_feel_by_bodyparts}
              
              view 'index', engine: 'html.erb', locals: { 
                has_data: has_data,
                user: user, 
                records: records, 
                account: user.url, 
                viz_1: viz_1,
                viz_2: viz_2,
                viz_3: viz_3,
                viz_4: viz_4,
                date_start: date_start,
                date_end: date_end,
                is_record: is_record,
                prompt_text: prompt_text}
            end
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
            
            is_record = false
            current_date = Time.now.strftime("%H").to_i <= 14 ? Date.today-1 : Date.today
            records = user.owned_records
            if records.length != 0
              is_record = records[-1].record_date == current_date.strftime('%Y-%m-%d').to_s ? true : false
            end

            Database::FomoRecordOrm.create(owner_id: user.id)

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

                is_record = false
                current_date = Time.now.strftime("%H").to_i <= 14 ? Date.today-1 : Date.today
                records = user.owned_records
                if records.length != 0
                  is_record = records[-1].record_date == current_date.strftime('%Y-%m-%d').to_s ? true : false
                end

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
                week_records = Database::RecordOrm.where(record_date: start_of_week..end_of_week)
                                                  .where(owner_id: user.id).all
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
            user = Database::UserOrm.where(url: account).first

            session[:watching] = user
            is_record = false
            current_date = Time.now.strftime("%H").to_i <= 14 ? Date.today-1 : Date.today
            records = user.owned_records
            if records.length != 0
              is_record = records[-1].record_date == current_date.strftime('%Y-%m-%d').to_s ? true : false
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

            # get the records from database
            week_records = Database::RecordOrm.where(record_date: start_of_week..end_of_week)
                                              .where(owner_id: user.id).all
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
          # POST /form/#{account}
          routing.post do
            user = session[:watching]
            fill_time = routing.params["fill_time"]
            q1_ans = routing.params["1"].to_i

            # Q2 ans string
            q2_ans = ""
            routing.params["q2_ans"].each_with_index do |ans, index|
              if index !=0
                q2_ans += "|"
              end
              q2_ans += ans
            end

            view 'form', engine: 'html.erb', locals: { 
              account: user.url, 
              user: user, 
              fill_time: fill_time, 
              q1_hours: q1_ans/60, 
              q1_mins: q1_ans%60, 
              q1_ans: q1_ans, 
              q2_ans: q2_ans,
              q3_ans: routing.params["3"],
              q4_ans: routing.params["4"],
              q5_ans: routing.params["5"],
              q6_ans: routing.params["6"],
              q7_ans: routing.params["7"],
              q8_ans: routing.params["8"],
              q9_ans: routing.params["9"],
            }
          end
        end
      end

      # questionnaire - question 2
      routing.on 'form_2' do
        routing.on String do |account|
          # POST /form_2/#{account}
          routing.post do
            user = session[:watching]

            # Q3 ans string
            q3_ans = ""
            if !routing.params["q3_ans"].nil?
              routing.params["q3_ans"].each_with_index do |ans, index|
                if index !=0
                  q3_ans += "|"
                end
                q3_ans += ans
              end
            else
              q3_ans = routing.params["3"]
            end

            view 'form_2', engine: 'html.erb', locals: { 
              account: user.url, 
              user: user, 
              fill_time: routing.params["fill_time"], 
              q1_ans: routing.params["1"],
              q2_ans: routing.params["2"],
              q3_ans: q3_ans,
              q4_ans: routing.params["4"],
              q5_ans: routing.params["5"],
              q6_ans: routing.params["6"],
              q7_ans: routing.params["7"],
              q8_ans: routing.params["8"],
              q9_ans: routing.params["9"]
            }
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
            if !routing.params["q2_ans"].nil?
              routing.params["q2_ans"].each_with_index do |ans, index|
                if index !=0
                  q2_ans += "|"
                end
                q2_ans += ans
              end
            else
              q2_ans = routing.params["2"]
            end

            view 'form_3', engine: 'html.erb', locals: { 
              account: user.url, 
              user: user, 
              fill_time: routing.params["fill_time"], 
              q1_ans: routing.params["1"], 
              q2_ans: q2_ans,
              q3_ans: routing.params["3"],
              q4_ans: routing.params["4"],
              q5_ans: routing.params["5"],
              q6_ans: routing.params["6"],
              q7_ans: routing.params["7"],
              q8_ans: routing.params["8"],
              q9_ans: routing.params["9"]
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

            # Q3 ans string
            q3_ans = ""
            if !routing.params["q3_ans"].nil?
              routing.params["q3_ans"].each_with_index do |ans, index|
                if index !=0
                  q3_ans += "|"
                end
                q3_ans += ans
              end
            else
              q3_ans = routing.params["3"]
            end

            view 'form_4', engine: 'html.erb', locals: { 
              account: user.url, 
              user: user, 
              fill_time: routing.params["fill_time"], 
              q1_ans: routing.params["1"], 
              q2_ans: routing.params["2"], 
              q3_ans: q3_ans,
              q4_ans: routing.params["4"],
              q5_ans: routing.params["5"],
              q6_ans: routing.params["6"],
              q7_ans: routing.params["7"],
              q8_ans: routing.params["8"],
              q9_ans: routing.params["9"]
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
              q4_ans: routing.params["4"],
              q5_ans: routing.params["5"],
              q6_ans: routing.params["6"],
              q7_ans: routing.params["7"],
              q8_ans: routing.params["8"],
              q9_ans: routing.params["9"]
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
              q5_ans: routing.params["5"],
              q6_ans: routing.params["6"],
              q7_ans: routing.params["7"],
              q8_ans: routing.params["8"],
              q9_ans: routing.params["9"]
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

            user_records = Database::RecordOrm.where(owner_id: user.id).all
            past_record_q7_ans = ""
            if routing.params["7"].empty?
              user_records.each do |record|
                q7_ans_record = Database::AnswerOrm.where(recordbook_id: record.id, question_num: 7).first
                if !q7_ans_record.nil? 
                  past_record_q7_ans = q7_ans_record.answer_content
                end
              end
            else
              past_record_q7_ans = routing.params["7"]
            end

            view 'form_7', engine: 'html.erb', locals: { 
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
              q8_ans: routing.params["8"],
              q9_ans: routing.params["9"],
              previous_q7ans: past_record_q7_ans
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
              q7_ans: routing.params["7"],
              q8_ans: routing.params["8"],
              q9_ans: routing.params["9"],
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
              q8_ans: routing.params["8"],
              q9_ans: routing.params["9"]
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
            countermeasurerecord = Database::CountermeasureRecordOrm.create(countermeasure_id: countermeasure_id, owner_id: user.id, is_try: is_try, selected_content: selected_content)

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

              record = Database::RecordOrm.create(access_time: 0, owner_id: user.id, fill_time: routing.params["fill_time"], record_date: record_date)
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

      routing.on 'form_record' do
        routing.on String do |record|
          # GET /form_record/#{record}
          routing.get do
            user = session[:watching]

            is_record = false
            current_date = Time.now.strftime("%H").to_i <= 14 ? Date.today-1 : Date.today
            records = user.owned_records
            if records.length != 0
              is_record = records[-1].record_date == current_date.strftime('%Y-%m-%d').to_s ? true : false
            end

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
