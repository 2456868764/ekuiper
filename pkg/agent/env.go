package agent

import (
	"os"
)

const (
	EnvNodeIP          = "NODE_IP"
	EnvNodePort        = "NODE_PORT"
	EnvNodeName        = "NODE_NAME"
	EnvNodeTag         = "NODE_TAG"
	EnvCoordinatorHost = "COORDINATOR_HOST"
)

func GetNodeName() string {
	return GetStringEnv(EnvNodeName, GetDefaultHostName())
}

func GetNodeTag() string {
	return GetStringEnv(EnvNodeTag, "")
}

func GetCoordinatorHost() string {
	return GetStringEnv(EnvCoordinatorHost, "")
}

func GetNodeIP() string {
	return GetStringEnv(EnvNodeIP, "")
}

func GetNodePort() string {
	return GetStringEnv(EnvNodePort, "9081")
}

func GetDefaultHostName() string {
	hostname, err := os.Hostname()
	if err != nil {
		return ""
	}
	return hostname
}

func GetStringEnv(name string, defvalue string) string {
	val, ex := os.LookupEnv(name)
	if ex {
		return val
	} else {
		return defvalue
	}
}
