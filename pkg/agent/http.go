package agent

import (
	"github.com/go-resty/resty/v2"
)

func Get(url string, params map[string]string, headers map[string]string) (*resty.Response, error) {
	client := resty.New()
	client.SetDebug(true)
	client.SetDebugBodyLimit(1000000)
	resp, err := client.R().
		SetQueryParams(params).
		SetHeaders(headers).
		Get(url)

	return resp, err
}

func Post(url string, data interface{}, headers map[string]string) (*resty.Response, error) {
	client := resty.New()
	client.SetDebug(true)
	client.SetDebugBodyLimit(1000000)
	resp, err := client.R().
		SetHeader("Content-Type", "application/json").
		SetHeaders(headers).
		SetBody(data).
		Post(url)
	return resp, err
}

func Put(url string, data interface{}, headers map[string]string) (*resty.Response, error) {
	client := resty.New()
	client.SetDebug(true)
	client.SetDebugBodyLimit(1000000)
	resp, err := client.R().
		SetHeader("Content-Type", "application/json").
		SetHeaders(headers).
		SetBody(data).
		Put(url)
	return resp, err
}

func Delete(url string, data interface{}, headers map[string]string) (*resty.Response, error) {
	client := resty.New()
	client.SetDebug(true)
	client.SetDebugBodyLimit(1000000)
	resp, err := client.R().
		SetHeader("Content-Type", "application/json").
		SetHeaders(headers).
		SetBody(data).
		Delete(url)
	return resp, err
}
