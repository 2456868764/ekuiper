package agent

import "time"

type Node struct {
	WorkerID        int32
	Name            string
	Tag             string
	IP              string
	Port            int32
	CoordinatorHost string
	LastSourcesTime time.Time
	LastSinksTime   time.Time
}

type WorkerRegisterReq struct {
	Name string `form:"name" binding:"required"`
	Tag  string `form:"tag"`
	IP   string `form:"ip" binding:"required"`
	Port int32  `form:"port" binding:"required"`
}

type WorkerRegisterResp struct {
	WorkerID int32 `json:"workerID"`
}

func (w WorkerRegisterResp) GetData() {

}

type WorkerUnRegisterReq struct {
	WorkerID int32 `form:"workerId" binding:"required"`
}

type WorkerHeartbeatReq struct {
	WorkerID        int32     `form:"workerId" binding:"required"`
	IP              string    `form:"ip" binding:"required"`
	Port            int32     `form:"port" binding:"required"`
	LastSourcesTime time.Time `form:"lastSourcesTime"`
}

type ConfigurationReq struct {
	WorkerID int32  `form:"workerId" binding:"required"`
	ConfType string `form:"confType" binding:"required"`
}

type ConfigurationResp struct {
	Data           map[string]string `json:"data"`
	LastUpdateTime time.Time         `json:"lastUpdateTime"`
}

func (w ConfigurationResp) GetData() {

}

type WorkerHeartbeatResp struct {
	LastSourcesTime time.Time `json:"lastSourcesTime"`
	LastSinksTime   time.Time `json:"lastSinksTime"`
	Kill            bool      `json:"kill"`
}

func (w WorkerHeartbeatResp) GetData() {

}

type DataInterface interface {
	GetData()
}

type Response struct {
	Code      int           `json:"code"`
	Message   string        `json:"message"`
	Data      DataInterface `json:"data,omitempty"`
	Error     string        `json:"error,omitempty"`
	OriginUrl string        `json:"originUrl"`
}
