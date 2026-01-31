# api/functions/email-templates.R
#
# Professional HTML email templates for SysNDD transactional emails.
# Following OWASP security guidelines and modern email design best practices.
#
# References:
# - MJML responsive email framework: https://mjml.io/
# - Mailjet transactional email guide: https://www.mailjet.com/blog/email-best-practices/
# - Postmark transactional templates: https://github.com/wildbit/postmark-templates

# Brand colors matching SysNDD frontend
SYSNDD_PRIMARY <- "#1565c0"
SYSNDD_PRIMARY_DARK <- "#0d47a1"
SYSNDD_TEXT <- "#2c3e50"
SYSNDD_TEXT_LIGHT <- "#666666"
SYSNDD_BACKGROUND <- "#f5f5f5"
SYSNDD_WHITE <- "#ffffff"
SYSNDD_SUCCESS <- "#28a745"
SYSNDD_WARNING <- "#ffc107"

#' Generate base HTML email wrapper
#'
#' Creates a responsive HTML email template wrapper with consistent branding.
#' Uses table-based layout for maximum email client compatibility.
#'
#' @param content The HTML content to wrap
#' @param preheader Optional preheader text (shows in email preview)
#' @return Complete HTML email string
email_wrapper <- function(content, preheader = "") {
  glue::glue('
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta http-equiv="X-UA-Compatible" content="IE=edge">
  <meta name="x-apple-disable-message-reformatting">
  <title>SysNDD</title>
  <!--[if mso]>
  <style type="text/css">
    table {{border-collapse:collapse;border-spacing:0;margin:0;}}
    div, td {{padding:0;}}
    div {{margin:0 !important;}}
  </style>
  <noscript>
    <xml>
      <o:OfficeDocumentSettings>
        <o:PixelsPerInch>96</o:PixelsPerInch>
      </o:OfficeDocumentSettings>
    </xml>
  </noscript>
  <![endif]-->
  <style type="text/css">
    body {{ margin: 0; padding: 0; background-color: {SYSNDD_BACKGROUND}; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; }}
    .email-container {{ max-width: 600px; margin: 0 auto; }}
    .email-header {{ background-color: {SYSNDD_PRIMARY}; padding: 24px; text-align: center; }}
    .email-header img {{ max-height: 50px; }}
    .email-header h1 {{ color: {SYSNDD_WHITE}; font-size: 24px; margin: 12px 0 0 0; font-weight: 600; }}
    .email-body {{ background-color: {SYSNDD_WHITE}; padding: 32px 24px; }}
    .email-body h2 {{ color: {SYSNDD_TEXT}; font-size: 20px; margin: 0 0 16px 0; font-weight: 600; }}
    .email-body p {{ color: {SYSNDD_TEXT}; font-size: 16px; line-height: 1.6; margin: 0 0 16px 0; }}
    .email-body .highlight {{ color: {SYSNDD_PRIMARY}; font-weight: 600; }}
    .btn {{ display: inline-block; background-color: {SYSNDD_PRIMARY}; color: {SYSNDD_WHITE} !important; text-decoration: none; padding: 14px 28px; border-radius: 6px; font-weight: 600; font-size: 16px; margin: 16px 0; }}
    .btn:hover {{ background-color: {SYSNDD_PRIMARY_DARK}; }}
    .info-box {{ background-color: #e3f2fd; border-left: 4px solid {SYSNDD_PRIMARY}; padding: 16px; margin: 20px 0; border-radius: 0 6px 6px 0; }}
    .info-box p {{ margin: 0; color: {SYSNDD_TEXT}; }}
    .warning-box {{ background-color: #fff3cd; border-left: 4px solid {SYSNDD_WARNING}; padding: 16px; margin: 20px 0; border-radius: 0 6px 6px 0; }}
    .warning-box p {{ margin: 0; color: {SYSNDD_TEXT}; }}
    .code-box {{ background-color: #f8f9fa; border: 1px solid #dee2e6; padding: 12px 16px; border-radius: 6px; font-family: "SFMono-Regular", Consolas, "Liberation Mono", Menlo, monospace; font-size: 14px; word-break: break-all; margin: 16px 0; }}
    .divider {{ border-top: 1px solid #e0e0e0; margin: 24px 0; }}
    .email-footer {{ background-color: {SYSNDD_BACKGROUND}; padding: 24px; text-align: center; }}
    .email-footer p {{ color: {SYSNDD_TEXT_LIGHT}; font-size: 13px; line-height: 1.5; margin: 0 0 8px 0; }}
    .email-footer a {{ color: {SYSNDD_PRIMARY}; text-decoration: none; }}
    .social-links {{ margin: 16px 0; }}
    .social-links a {{ display: inline-block; margin: 0 8px; }}
    @media only screen and (max-width: 600px) {{
      .email-body {{ padding: 24px 16px; }}
      .btn {{ display: block; text-align: center; }}
    }}
  </style>
</head>
<body>
  <!-- Preheader text (hidden but shows in email preview) -->
  <div style="display: none; max-height: 0px; overflow: hidden;">
    {preheader}
  </div>
  <!-- Preheader spacer -->
  <div style="display: none; max-height: 0px; overflow: hidden;">
    &nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;&zwnj;&nbsp;
  </div>

  <table role="presentation" cellspacing="0" cellpadding="0" border="0" width="100%" style="background-color: {SYSNDD_BACKGROUND};">
    <tr>
      <td align="center" style="padding: 24px 12px;">
        <table role="presentation" cellspacing="0" cellpadding="0" border="0" class="email-container" style="max-width: 600px; width: 100%;">
          <!-- Header -->
          <tr>
            <td class="email-header" style="background-color: {SYSNDD_PRIMARY}; padding: 24px; text-align: center; border-radius: 8px 8px 0 0;">
              <img src="https://sysndd.org/brain-neurodevelopmental-disorders-sysndd.png" alt="SysNDD Logo" style="max-height: 50px; margin-bottom: 8px;">
              <h1 style="color: {SYSNDD_WHITE}; font-size: 22px; margin: 8px 0 0 0; font-weight: 600;">SysNDD</h1>
            </td>
          </tr>
          <!-- Body -->
          <tr>
            <td class="email-body" style="background-color: {SYSNDD_WHITE}; padding: 32px 24px;">
              {content}
            </td>
          </tr>
          <!-- Footer -->
          <tr>
            <td class="email-footer" style="background-color: {SYSNDD_BACKGROUND}; padding: 24px; text-align: center; border-radius: 0 0 8px 8px;">
              <p style="color: {SYSNDD_TEXT_LIGHT}; font-size: 13px; line-height: 1.5; margin: 0 0 8px 0;">
                <a href="https://sysndd.org" style="color: {SYSNDD_PRIMARY}; text-decoration: none; font-weight: 600;">SysNDD.org</a>
                &nbsp;|&nbsp;
                <a href="https://github.com/berntpopp/sysndd" style="color: {SYSNDD_PRIMARY}; text-decoration: none;">GitHub</a>
                &nbsp;|&nbsp;
                <a href="https://berntpopp.github.io/sysndd/" style="color: {SYSNDD_PRIMARY}; text-decoration: none;">Documentation</a>
              </p>
              <p style="color: {SYSNDD_TEXT_LIGHT}; font-size: 12px; margin: 12px 0 0 0;">
                The expert curated database of gene disease relationships<br>in neurodevelopmental disorders.
              </p>
              <p style="color: #999999; font-size: 11px; margin: 16px 0 0 0;">
                This is an automated message from SysNDD. Please do not reply to this email.<br>
                &copy; {format(Sys.Date(), "%Y")} SysNDD. All rights reserved.
              </p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
', .open = "{", .close = "}")
}


#' Password Reset Email Template
#'
#' Creates a professional password reset email with clear CTA button.
#'
#' @param reset_url The password reset URL with JWT token
#' @param user_name Optional user name for personalization
#' @param expiry_minutes Token expiry time in minutes (default 60)
#' @return Complete HTML email string
email_password_reset <- function(reset_url, user_name = NULL, expiry_minutes = 60) {
  greeting <- if (!is.null(user_name) && nchar(user_name) > 0) {
    glue::glue('<p style="color: {SYSNDD_TEXT}; font-size: 16px; line-height: 1.6; margin: 0 0 16px 0;">Hello <span class="highlight" style="color: {SYSNDD_PRIMARY}; font-weight: 600;">{user_name}</span>,</p>')
  } else {
    glue::glue('<p style="color: {SYSNDD_TEXT}; font-size: 16px; line-height: 1.6; margin: 0 0 16px 0;">Hello,</p>')
  }

  content <- glue::glue('
<h2 style="color: {SYSNDD_TEXT}; font-size: 20px; margin: 0 0 16px 0; font-weight: 600;">Password Reset Request</h2>

{greeting}

<p style="color: {SYSNDD_TEXT}; font-size: 16px; line-height: 1.6; margin: 0 0 16px 0;">
  We received a request to reset the password for your SysNDD account.
  Click the button below to create a new password:
</p>

<table role="presentation" cellspacing="0" cellpadding="0" border="0" style="margin: 24px auto;">
  <tr>
    <td style="border-radius: 6px; background-color: {SYSNDD_PRIMARY};">
      <a href="{reset_url}" target="_blank" style="display: inline-block; background-color: {SYSNDD_PRIMARY}; color: {SYSNDD_WHITE}; text-decoration: none; padding: 14px 28px; border-radius: 6px; font-weight: 600; font-size: 16px;">
        Reset Password
      </a>
    </td>
  </tr>
</table>

<div class="info-box" style="background-color: #e3f2fd; border-left: 4px solid {SYSNDD_PRIMARY}; padding: 16px; margin: 20px 0; border-radius: 0 6px 6px 0;">
  <p style="margin: 0; color: {SYSNDD_TEXT}; font-size: 14px;">
    <strong>This link will expire in {expiry_minutes} minutes.</strong><br>
    If you did not request this password reset, you can safely ignore this email.
  </p>
</div>

<p style="color: {SYSNDD_TEXT_LIGHT}; font-size: 14px; line-height: 1.6; margin: 20px 0 0 0;">
  If the button above does not work, copy and paste this link into your browser:
</p>
<div class="code-box" style="background-color: #f8f9fa; border: 1px solid #dee2e6; padding: 12px 16px; border-radius: 6px; font-family: monospace; font-size: 12px; word-break: break-all; margin: 8px 0 0 0; color: {SYSNDD_TEXT_LIGHT};">
  {reset_url}
</div>
', .open = "{", .close = "}")

  email_wrapper(content, preheader = "Reset your SysNDD password - link expires in 60 minutes")
}


#' Registration Request Email Template
#'
#' Sent to users after they submit a registration request.
#'
#' @param user_info Named list with user details (user_name, email, first_name, family_name)
#' @return Complete HTML email string
email_registration_request <- function(user_info) {
  first_name <- user_info$first_name %||% user_info$user_name %||% "there"

  content <- glue::glue('
<h2 style="color: {SYSNDD_TEXT}; font-size: 20px; margin: 0 0 16px 0; font-weight: 600;">Registration Request Received</h2>

<p style="color: {SYSNDD_TEXT}; font-size: 16px; line-height: 1.6; margin: 0 0 16px 0;">
  Hello <span class="highlight" style="color: {SYSNDD_PRIMARY}; font-weight: 600;">{first_name}</span>,
</p>

<p style="color: {SYSNDD_TEXT}; font-size: 16px; line-height: 1.6; margin: 0 0 16px 0;">
  Thank you for your interest in contributing to SysNDD! We have received your registration request and our curators will review it shortly.
</p>

<div class="info-box" style="background-color: #e3f2fd; border-left: 4px solid {SYSNDD_PRIMARY}; padding: 16px; margin: 20px 0; border-radius: 0 6px 6px 0;">
  <p style="margin: 0 0 8px 0; color: {SYSNDD_TEXT}; font-size: 14px;"><strong>Registration Details:</strong></p>
  <table style="font-size: 14px; color: {SYSNDD_TEXT};">
    <tr><td style="padding: 4px 12px 4px 0; color: {SYSNDD_TEXT_LIGHT};">Username:</td><td style="font-weight: 600;">{user_info$user_name}</td></tr>
    <tr><td style="padding: 4px 12px 4px 0; color: {SYSNDD_TEXT_LIGHT};">Email:</td><td>{user_info$email}</td></tr>
    <tr><td style="padding: 4px 12px 4px 0; color: {SYSNDD_TEXT_LIGHT};">Name:</td><td>{user_info$first_name} {user_info$family_name}</td></tr>
  </table>
</div>

<p style="color: {SYSNDD_TEXT}; font-size: 16px; line-height: 1.6; margin: 0 0 16px 0;">
  <strong>What happens next?</strong>
</p>
<ul style="color: {SYSNDD_TEXT}; font-size: 15px; line-height: 1.8; margin: 0 0 16px 0; padding-left: 20px;">
  <li>Our curators will review your registration request</li>
  <li>Once approved, you will receive an email with your login credentials</li>
  <li>You can then sign in and start contributing to SysNDD</li>
</ul>

<p style="color: {SYSNDD_TEXT_LIGHT}; font-size: 14px; line-height: 1.6; margin: 20px 0 0 0;">
  If you have any questions, please contact our team at
  <a href="mailto:curator@sysndd.org" style="color: {SYSNDD_PRIMARY}; text-decoration: none;">curator@sysndd.org</a>
</p>
', .open = "{", .close = "}")

  email_wrapper(content, preheader = "Your SysNDD registration request has been received")
}


#' Account Approval Email Template
#'
#' Sent when a curator approves a user registration.
#'
#' @param user_name The user\'s display name
#' @param temp_password The temporary password generated
#' @param login_url The login page URL
#' @return Complete HTML email string
email_account_approved <- function(user_name, temp_password, login_url = "https://sysndd.org/Login") {
  content <- glue::glue('
<h2 style="color: {SYSNDD_TEXT}; font-size: 20px; margin: 0 0 16px 0; font-weight: 600;">Your Account Has Been Approved!</h2>

<p style="color: {SYSNDD_TEXT}; font-size: 16px; line-height: 1.6; margin: 0 0 16px 0;">
  Hello <span class="highlight" style="color: {SYSNDD_PRIMARY}; font-weight: 600;">{user_name}</span>,
</p>

<p style="color: {SYSNDD_TEXT}; font-size: 16px; line-height: 1.6; margin: 0 0 16px 0;">
  Great news! Your registration for SysNDD has been approved by our curators. You can now sign in and start contributing to our database of neurodevelopmental disorder gene relationships.
</p>

<div class="warning-box" style="background-color: #fff3cd; border-left: 4px solid {SYSNDD_WARNING}; padding: 16px; margin: 20px 0; border-radius: 0 6px 6px 0;">
  <p style="margin: 0 0 8px 0; color: {SYSNDD_TEXT}; font-size: 14px;"><strong>Your Temporary Password:</strong></p>
  <div class="code-box" style="background-color: {SYSNDD_WHITE}; border: 1px solid #dee2e6; padding: 12px 16px; border-radius: 6px; font-family: monospace; font-size: 16px; margin: 8px 0; font-weight: 600; color: {SYSNDD_TEXT};">
    {temp_password}
  </div>
  <p style="margin: 8px 0 0 0; color: {SYSNDD_TEXT}; font-size: 13px;">
    Please change this password immediately after your first login for security.
  </p>
</div>

<table role="presentation" cellspacing="0" cellpadding="0" border="0" style="margin: 24px auto;">
  <tr>
    <td style="border-radius: 6px; background-color: {SYSNDD_SUCCESS};">
      <a href="{login_url}" target="_blank" style="display: inline-block; background-color: {SYSNDD_SUCCESS}; color: {SYSNDD_WHITE}; text-decoration: none; padding: 14px 28px; border-radius: 6px; font-weight: 600; font-size: 16px;">
        Sign In to SysNDD
      </a>
    </td>
  </tr>
</table>

<div style="border-top: 1px solid #e0e0e0; margin: 24px 0;"></div>

<p style="color: {SYSNDD_TEXT}; font-size: 16px; line-height: 1.6; margin: 0 0 8px 0;">
  <strong>Getting Started:</strong>
</p>
<ul style="color: {SYSNDD_TEXT}; font-size: 15px; line-height: 1.8; margin: 0; padding-left: 20px;">
  <li>Sign in using your username and temporary password</li>
  <li>Update your password in your account settings</li>
  <li>Explore our curation guidelines in the <a href="https://berntpopp.github.io/sysndd/" style="color: {SYSNDD_PRIMARY};">documentation</a></li>
  <li>Start reviewing and contributing to gene-disease relationships</li>
</ul>
', .open = "{", .close = "}")

  email_wrapper(content, preheader = "Welcome to SysNDD - Your account has been approved!")
}


#' Re-Review Request Email Template
#'
#' Sent when a user requests a new batch of entities for re-review.
#'
#' @param user_info Named list with user details
#' @param batch_info Optional batch details
#' @return Complete HTML email string
email_rereview_request <- function(user_info, batch_info = NULL) {
  user_name <- user_info$user_name %||% "User"

  batch_section <- if (!is.null(batch_info)) {
    glue::glue('
<div class="info-box" style="background-color: #e3f2fd; border-left: 4px solid {SYSNDD_PRIMARY}; padding: 16px; margin: 20px 0; border-radius: 0 6px 6px 0;">
  <p style="margin: 0 0 8px 0; color: {SYSNDD_TEXT}; font-size: 14px;"><strong>Batch Details:</strong></p>
  <p style="margin: 0; color: {SYSNDD_TEXT}; font-size: 14px;">{batch_info}</p>
</div>
', .open = "{", .close = "}")
  } else {
    ""
  }

  content <- glue::glue('
<h2 style="color: {SYSNDD_TEXT}; font-size: 20px; margin: 0 0 16px 0; font-weight: 600;">Re-Review Batch Request Submitted</h2>

<p style="color: {SYSNDD_TEXT}; font-size: 16px; line-height: 1.6; margin: 0 0 16px 0;">
  Hello <span class="highlight" style="color: {SYSNDD_PRIMARY}; font-weight: 600;">{user_name}</span>,
</p>

<p style="color: {SYSNDD_TEXT}; font-size: 16px; line-height: 1.6; margin: 0 0 16px 0;">
  Your request for a new re-review batch has been submitted to our curators. They will review and activate your application shortly.
</p>

{batch_section}

<div class="info-box" style="background-color: #e3f2fd; border-left: 4px solid {SYSNDD_PRIMARY}; padding: 16px; margin: 20px 0; border-radius: 0 6px 6px 0;">
  <p style="margin: 0 0 8px 0; color: {SYSNDD_TEXT}; font-size: 14px;"><strong>Requesting User Information:</strong></p>
  <table style="font-size: 14px; color: {SYSNDD_TEXT};">
    <tr><td style="padding: 4px 12px 4px 0; color: {SYSNDD_TEXT_LIGHT};">Username:</td><td style="font-weight: 600;">{user_info$user_name}</td></tr>
    <tr><td style="padding: 4px 12px 4px 0; color: {SYSNDD_TEXT_LIGHT};">Email:</td><td>{user_info$email}</td></tr>
    <tr><td style="padding: 4px 12px 4px 0; color: {SYSNDD_TEXT_LIGHT};">ORCID:</td><td><a href="https://orcid.org/{user_info$orcid}" style="color: {SYSNDD_PRIMARY};">{user_info$orcid}</a></td></tr>
  </table>
</div>

<p style="color: {SYSNDD_TEXT}; font-size: 16px; line-height: 1.6; margin: 0 0 16px 0;">
  <strong>What happens next?</strong>
</p>
<ul style="color: {SYSNDD_TEXT}; font-size: 15px; line-height: 1.8; margin: 0; padding-left: 20px;">
  <li>Our curators will review your request</li>
  <li>Once approved, your new batch will be activated</li>
  <li>You will receive a notification when the batch is ready</li>
</ul>

<p style="color: {SYSNDD_TEXT_LIGHT}; font-size: 14px; line-height: 1.6; margin: 20px 0 0 0;">
  Thank you for your continued contributions to SysNDD!
</p>
', .open = "{", .close = "}")

  email_wrapper(content, preheader = "Your SysNDD re-review batch request has been submitted")
}


#' Generic Notification Email Template
#'
#' For general system notifications.
#'
#' @param subject_text The notification title/subject
#' @param body_content The main message content (can include HTML)
#' @param user_name Optional user name for personalization
#' @return Complete HTML email string
email_notification <- function(subject_text, body_content, user_name = NULL) {
  greeting <- if (!is.null(user_name) && nchar(user_name) > 0) {
    glue::glue('<p style="color: {SYSNDD_TEXT}; font-size: 16px; line-height: 1.6; margin: 0 0 16px 0;">Hello <span class="highlight" style="color: {SYSNDD_PRIMARY}; font-weight: 600;">{user_name}</span>,</p>')
  } else {
    ""
  }

  content <- glue::glue('
<h2 style="color: {SYSNDD_TEXT}; font-size: 20px; margin: 0 0 16px 0; font-weight: 600;">{subject_text}</h2>

{greeting}

<div style="color: {SYSNDD_TEXT}; font-size: 16px; line-height: 1.6;">
  {body_content}
</div>
', .open = "{", .close = "}")

  email_wrapper(content, preheader = subject_text)
}
