# frozen_string_literal: true

# 通信ログビューア。アクセストークン等を含みうるので、ローカルからのアクセスかつ LOGS_TOKEN での Basic 認証を必須にしている。
# ssh -R で公開している場合、中継サーバー上からのリクエストも 127.0.0.1 からに見えるので、request.local? だけでは守れない
class LogsController < ApplicationController
  before_action :require_local_request
  before_action :require_logs_token

  def index
    @logs = CommunicationLog.recent.limit(200)
    @logs = @logs.where(direction: params[:direction]) if params[:direction].present?
    @logs = @logs.where(category: params[:category]) if params[:category].present?
  end

  def show
    @log = CommunicationLog.find(params[:id])
  end

  def destroy_all
    CommunicationLog.delete_all
    redirect_to(logs_path, notice: "ログを削除しました")
  end

  private

  def require_local_request
    head(:forbidden) unless request.local?
  end

  # ユーザー名は任意、パスワードに LOGS_TOKEN を入力する。未設定なら誰も見られない
  def require_logs_token
    token = ENV["LOGS_TOKEN"].to_s
    return head(:forbidden) if token.empty?

    authenticate_or_request_with_http_basic("logs") do |_user, password|
      ActiveSupport::SecurityUtils.secure_compare(password, token)
    end
  end
end
