package agent

import (
	"encoding/json"
	"fmt"
)

type Client struct {
}

func NewClient() *Client {
	return &Client{}
}

func (c *Client) RegisterNode(node *Node) (*Node, error) {
	url := fmt.Sprintf("http://%s/api/node/register", node.CoordinatorHost)
	req := &WorkerRegisterReq{
		Name: node.Name,
		IP:   node.IP,
		Tag:  node.Tag,
		Port: node.Port,
	}
	resp, err := Post(url, req, nil)
	if err != nil {
		return nil, err
	}
	//if !resp.IsSuccess() {
	//	return nil, fmt.Errorf("register node failed, status code %d", resp.StatusCode)
	//}
	data := &WorkerRegisterResp{}
	response := Response{
		Data: data,
	}
	err2 := json.Unmarshal(resp.Body(), &response)
	if err2 != nil {
		return nil, err
	}
	if response.Code > 0 {
		return nil, fmt.Errorf("register node failed, response code %d response msg:%s", response.Code, response.Message)
	}

	node.WorkerID = response.Data.(*WorkerRegisterResp).WorkerID
	return node, nil
}

func (c *Client) UnRegisterNode(node *Node) error {
	url := fmt.Sprintf("http://%s/api/node/unregister", node.CoordinatorHost)
	req := &WorkerUnRegisterReq{
		WorkerID: node.WorkerID,
	}
	resp, err := Post(url, req, nil)
	if err != nil {
		return err
	}
	if !resp.IsSuccess() {
		return fmt.Errorf("register node failed, status code %d", resp.StatusCode)
	}

	return nil
}

func (c *Client) Heartbeat(node *Node) (*WorkerHeartbeatResp, error) {
	url := fmt.Sprintf("http://%s/api/node/heartbeat", node.CoordinatorHost)
	req := &WorkerHeartbeatReq{
		IP:              node.IP,
		Port:            node.Port,
		WorkerID:        node.WorkerID,
		LastSourcesTime: node.LastSourcesTime,
	}
	resp, err := Post(url, req, nil)
	if err != nil {
		return nil, err
	}
	//if !resp.IsSuccess() {
	//	return nil, fmt.Errorf("register node failed, status code %d", resp.StatusCode)
	//}
	data := &WorkerHeartbeatResp{}
	response := Response{
		Data: data,
	}
	err2 := json.Unmarshal(resp.Body(), &response)
	if err2 != nil {
		return nil, err
	}
	if response.Code > 0 {
		return nil, fmt.Errorf("register node failed, response code %d response msg:%s", response.Code, response.Message)
	}

	result := response.Data.(*WorkerHeartbeatResp)
	return result, nil
}

func (c *Client) LoadConfiguration(confType string, node *Node) (*ConfigurationResp, error) {
	req := &ConfigurationReq{
		WorkerID: node.WorkerID,
		ConfType: confType,
	}
	url := fmt.Sprintf("http://%s/api/configuration/load", node.CoordinatorHost)
	resp, err := Post(url, req, nil)
	if err != nil {
		return nil, err
	}
	//if !resp.IsSuccess() {
	//	return nil, fmt.Errorf("load global config failed, status code %d", resp.StatusCode)
	//}
	data := &ConfigurationResp{}
	response := Response{
		Data: data,
	}
	err2 := json.Unmarshal(resp.Body(), &response)
	if err2 != nil {
		return nil, err2
	}
	if response.Code > 0 {
		return nil, fmt.Errorf("register node failed, response code %d response msg:%s", response.Code, response.Message)
	}

	result := response.Data.(*ConfigurationResp)
	return result, nil
}
