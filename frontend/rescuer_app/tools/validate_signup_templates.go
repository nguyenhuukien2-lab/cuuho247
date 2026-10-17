// Read-only validation with Go's actual standard template engines. No custom
// FuncMap, network calls, production configuration, or credentials are used.
package main

import (
	"bytes"
	"fmt"
	"html"
	htmltemplate "html/template"
	"os"
	"strings"
	texttemplate "text/template"
)

type emailData struct {
	Data            map[string]any
	Email           string
	Token           string
	ConfirmationURL string
}

func must(err error) {
	if err != nil {
		fmt.Fprintln(os.Stderr, "FAIL:", err)
		os.Exit(1)
	}
}

func require(ok bool, message string) {
	if !ok {
		must(fmt.Errorf("%s", message))
	}
}

func main() {
	if len(os.Args) < 3 {
		must(fmt.Errorf("usage: validate_signup_templates HTML SUBJECT [PREVIOUS_HTML]"))
	}
	bodyBytes, err := os.ReadFile(os.Args[1])
	must(err)
	subjectBytes, err := os.ReadFile(os.Args[2])
	must(err)
	body, err := htmltemplate.New("confirmation").Parse(string(bodyBytes))
	must(err)
	subject, err := texttemplate.New("subject").Parse(string(subjectBytes))
	must(err)
	var previous *htmltemplate.Template
	if len(os.Args) > 3 {
		before, err := os.ReadFile(os.Args[3])
		must(err)
		previous, err = htmltemplate.New("previous").Parse(string(before))
		must(err)
	}
	cases := []struct {
		name    string
		data    map[string]any
		partner bool
	}{
		{"partner-account-type", map[string]any{"account_type": "rescuer_partner"}, true},
		{"partner-boolean-flag", map[string]any{"partner_registration": true}, true},
		{"partner-both", map[string]any{"account_type": "rescuer_partner", "partner_registration": true}, true},
		{"partner-type-overrides-false-flag", map[string]any{"account_type": "rescuer_partner", "partner_registration": false}, true},
		{"partner-flag-overrides-customer-type", map[string]any{"account_type": "customer", "partner_registration": true}, true},
		{"customer-account-type", map[string]any{"account_type": "customer"}, false},
		{"customer-false-flag", map[string]any{"partner_registration": false}, false},
		{"customer-empty-metadata", map[string]any{}, false},
		{"customer-nil-metadata", nil, false},
		{"customer-string-false-is-not-boolean", map[string]any{"partner_registration": "false"}, false},
		{"customer-string-true-is-not-boolean", map[string]any{"partner_registration": "true"}, false},
		{"customer-numeric-flag", map[string]any{"partner_registration": 1}, false},
		{"customer-malformed-account-type", map[string]any{"account_type": 42}, false},
	}
	const otp = "012345" // Synthetic fixture only; never printed.
	const confirmationURL = "https://example.com/auth/v1/verify?token=fixture-only&type=signup&redirect_to=https%3A%2F%2Fexample.com%2Fexisting-customer-callback"
	for _, tc := range cases {
		for _, fallback := range []bool{false, true} {
			metadata := map[string]any{}
			for key, value := range tc.data {
				metadata[key] = value
			}
			if !fallback {
				metadata["full_name"] = "Đối tác kiểm thử"
				metadata["registered_at"] = "21:19 - 16/10/2026"
			}
			if tc.data == nil && fallback {
				metadata = nil
			}
			data := emailData{metadata, "fixture@example.invalid", otp, confirmationURL}
			var out, title bytes.Buffer
			must(body.Execute(&out, data))
			must(subject.Execute(&title, data))
			rendered := out.String()
			require(!strings.Contains(rendered, "<no value>") && !strings.Contains(rendered, "<nil>"), tc.name+": missing metadata leaked")
			if tc.partner {
				require(strings.Contains(rendered, otp), tc.name+": OTP missing")
				require(strings.Contains(rendered, "MÃ XÁC NHẬN EMAIL CỦA BẠN"), tc.name+": OTP label missing")
				require(!strings.Contains(rendered, "href=") && !strings.Contains(rendered, "example.com/auth/v1/verify"), tc.name+": confirmation link leaked into partner email")
				require(strings.TrimSpace(title.String()) == "Cứu Hộ 24/7 | Xác nhận email đăng ký đối tác", tc.name+": incorrect partner subject")
				if previous != nil {
					var before bytes.Buffer
					must(previous.Execute(&before, data))
					require(strings.Join(strings.Fields(before.String()), " ") == strings.Join(strings.Fields(rendered), " "), tc.name+": existing partner email changed")
				}
			} else {
				require(strings.Contains(rendered, `href="`+html.EscapeString(confirmationURL)+`"`), tc.name+": existing customer confirmation URL not preserved")
				require(!strings.Contains(rendered, otp) && !strings.Contains(rendered, "MÃ XÁC NHẬN EMAIL CỦA BẠN"), tc.name+": OTP leaked into customer email")
				require(!strings.Contains(rendered, "nhập mã") && !strings.Contains(rendered, "Gửi lại mã"), tc.name+": customer instructed to use OTP")
				require(strings.TrimSpace(title.String()) == "Cứu Hộ 24/7 | Xác nhận địa chỉ email", tc.name+": incorrect customer subject")
			}
			if fallback {
				require(strings.Contains(rendered, "Chưa cung cấp") && strings.Contains(rendered, "Chưa có thông tin"), tc.name+": fallback missing")
			}
		}
		fmt.Println("PASS:", tc.name, "(full and missing display metadata)")
	}
	var escaped bytes.Buffer
	must(body.Execute(&escaped, emailData{
		Data:  map[string]any{"account_type": "rescuer_partner", "full_name": `<script>alert("fixture")</script>`},
		Email: "fixture@example.invalid", Token: otp, ConfirmationURL: confirmationURL,
	}))
	require(!strings.Contains(escaped.String(), "<script>"), "metadata must be HTML escaped")
	require(strings.Contains(escaped.String(), "&lt;script&gt;"), "escaped name missing")
	fmt.Println("PASS: metadata HTML escaping")
	fmt.Println("GO_TEMPLATE_VALIDATION=PASS (27 renders; built-ins only; subject checked for both account types)")
}
