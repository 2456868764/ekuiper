package agent

import (
	"encoding/json"
	"fmt"
	"os"
	"path"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/lf-edge/ekuiper/internal/conf"
	"github.com/lf-edge/ekuiper/internal/meta"
	"gopkg.in/yaml.v3"
)

var (
	logger = conf.Log
)

const (
	defaultHeartbeat = 10 * time.Second
)

type CoordinatorAgent struct {
	Node              *Node
	Client            *Client
	heartbeatInterval time.Duration
	globalConfig      *ConfigurationResp
	sourcesConfig     *ConfigurationResp
}

func NewCoordinatorAgent() *CoordinatorAgent {
	return &CoordinatorAgent{
		Node:              NewNode(),
		Client:            NewClient(),
		heartbeatInterval: defaultHeartbeat,
	}
}

func NewNode() *Node {
	port, _ := strconv.Atoi(GetNodePort())
	return &Node{
		Name:            GetNodeName(),
		Tag:             GetNodeTag(),
		IP:              GetNodeIP(),
		Port:            int32(port),
		CoordinatorHost: GetCoordinatorHost(),
		WorkerID:        0,
	}
}

func (e *CoordinatorAgent) Init() error {
	logger.Infof("Start to init coodinator agent")
	// start to registe node
	logger.Infof("Start to register node %s", e.Node.Name)
	newNode, err := e.Client.RegisterNode(e.Node)
	if err != nil {
		return err
	}
	e.Node = newNode

	// start to get global config
	logger.Infof("Start to load global yaml configuration")
	globalConfig, err2 := e.Client.LoadConfiguration("global", e.Node)
	if err2 != nil {
		return err2
	}
	e.globalConfig = globalConfig
	// start to get Datasources
	logger.Infof("Start to load datasource yaml configuration")
	sourcesConfig, err3 := e.Client.LoadConfiguration("source", e.Node)
	if err3 != nil {
		return err3
	}
	e.sourcesConfig = sourcesConfig
	// start to write global yaml
	confDir, err := conf.GetConfLoc()
	if err != nil {
		return err
	}

	globalYamlContent := e.globalConfig.Data["global"]
	if len(strings.Trim(globalYamlContent, " ")) == 0 {
		return fmt.Errorf("global kuiper yaml configuration is empty")
	}
	logger.Infof("Start to write kuiper.yaml to dir:%s", confDir)
	kuiperYaml := path.Join(confDir, conf.ConfFileName)
	os.Remove(kuiperYaml)
	if err := os.WriteFile(kuiperYaml, []byte(globalYamlContent), 0644); err != nil {
		return err
	}
	// clear all local datasource configuration
	os.Remove(path.Join(confDir, "mqtt_source.yaml"))
	e.deleteYAMLFiles(path.Join(confDir, "sources"))
	// start to write datasource.yaml
	for pluginName, pluginYaml := range e.sourcesConfig.Data {
		dir := path.Join(confDir, "sources")
		fileName := pluginName
		if "mqtt" == pluginName {
			fileName = "mqtt_source"
			dir = confDir
		}
		filePath := path.Join(dir, fileName+`.yaml`)
		logger.Infof("Start to write datasource:%s to file:%s", pluginName, filePath)
		if err := os.WriteFile(filePath, []byte(pluginYaml), 0644); err != nil {
			return err
		}
	}
	e.Node.LastSourcesTime = e.sourcesConfig.LastUpdateTime
	return nil
}

func (e *CoordinatorAgent) deleteYAMLFiles(dir string) error {
	err := filepath.Walk(dir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if !info.IsDir() && filepath.Ext(info.Name()) == ".yaml" {
			if err := os.Remove(path); err != nil {
				return fmt.Errorf("failed to remove file %s: %w", path, err)
			}
			fmt.Printf("Deleted file: %s\n", path)
		}
		return nil
	})
	if err != nil {
		return fmt.Errorf("error walking the path %s: %w", dir, err)
	}
	return nil
}

func (e *CoordinatorAgent) Run(stopChan <-chan struct{}) error {
	// start to check heatbeat
	go e.startHeartbeat(stopChan)
	return nil
}

func (e *CoordinatorAgent) startHeartbeat(stopChan <-chan struct{}) error {
	ticker := time.NewTicker(e.heartbeatInterval)
	defer ticker.Stop()
	for {
		select {
		case <-ticker.C:
			e.checkHeartbeat()
		case <-stopChan:
			return nil
		}
	}
}

func (e *CoordinatorAgent) checkHeartbeat() error {
	workerHeartbeatResp, err := e.Client.Heartbeat(e.Node)
	if err != nil {
		logger.Infof("[engine] heartbeat error %s", err)
		return nil
	}
	// Need check kill status
	if workerHeartbeatResp.Kill == true {
		logger.Infof("[engine] heartbeat killed, node existed")
		// Start to stop all rules
		// os.Exit
		os.Exit(1)
	}
	// TODO need reload datasource
	if e.sourcesConfig.LastUpdateTime.Before(workerHeartbeatResp.LastSourcesTime) {
		logger.Infof("[engine] sources changed, need reload")
		e.reloadSources()
	}
	// TODO need reload sinks
	if e.sourcesConfig.LastUpdateTime.Before(workerHeartbeatResp.LastSinksTime) {
		logger.Infof("[engine] sinks changed, need reload")
		e.reloadSinks()
	}
	return nil
}

func (e *CoordinatorAgent) reloadSources() {
	logger.Infof("[engine] start to reload sources")
	newSourcesConfig, err := e.Client.LoadConfiguration("source", e.Node)
	if err != nil {
		logger.Error("[engine] reload sources error %s", err)
		return
	}
	if newSourcesConfig.LastUpdateTime.After(e.sourcesConfig.LastUpdateTime) {
		logger.Infof("[engine] sources changed, need reload")
		toModify := make([]string, 0)
		toAdd := make([]string, 0)
		toDelete := make([]string, 0)

		for key, value := range newSourcesConfig.Data {
			if _, exists := e.sourcesConfig.Data[key]; !exists {
				toAdd = append(toAdd, key)
			} else {
				if e.sourcesConfig.Data[key] != value {
					toModify = append(toModify, key)
				}
			}
		}

		for key, _ := range e.sourcesConfig.Data {
			if _, exists := newSourcesConfig.Data[key]; !exists {
				toDelete = append(toDelete, key)
			}
		}

		for _, plugin := range toAdd {
			logger.Infof("[engine] Add source plugin: %s", plugin)
			pluginData := make(map[string]interface{})
			if err := yaml.Unmarshal([]byte(newSourcesConfig.Data[plugin]), &pluginData); err != nil {
				logger.Errorf("[engine] unmarshal source %s error %s", plugin, err)
				continue
			}
			//for confKey, confValue := range pluginData {
			//
			//}
		}

		for _, plugin := range toModify {
			logger.Infof("[engine] Modify source %s", plugin)
			oldPluginData := make(map[string]interface{})
			newPluginData := make(map[string]interface{})
			if err := yaml.Unmarshal([]byte(e.sourcesConfig.Data[plugin]), &oldPluginData); err != nil {
				logger.Errorf("[engine] unmarshal old source %s error %s", plugin, err)
				continue
			}
			if err := yaml.Unmarshal([]byte(newSourcesConfig.Data[plugin]), &newPluginData); err != nil {
				logger.Errorf("[engine] unmarshal new source %s error %s", plugin, err)
				continue
			}
			// Compare with old and new, to get toModify , toDelete, toAdd
			for confKey, confValue := range newPluginData {
				if _, exists := oldPluginData[confKey]; !exists {
					logger.Infof("[engine] Add source %s, key %s, value %s", plugin, confKey, confValue)
					byteConfValue, err := json.Marshal(confValue)
					if err != nil {
						logger.Errorf("[engine] json marshal confValue %v err:%v", confValue, err)
						continue
					}
					err = meta.AddSourceConfKey(plugin, confKey, "en_US", byteConfValue)
					if err != nil {
						logger.Errorf("[engine] add source %s error %s", plugin, err)
					}
				} else {
					if oldPluginData[confKey] != confValue {
						logger.Infof("[engine] Modify source %s, key %s, value %s", plugin, confKey, confValue)
						// delete first and add again
						err := meta.DelSourceConfKey(plugin, confKey, "en_US")
						if err != nil {
							logger.Errorf("[engine] delete source %s error %s", plugin, err)
						}
						byteConfValue, err := json.Marshal(confValue)
						err = meta.AddSourceConfKey(plugin, confKey, "en_US", byteConfValue)
						if err != nil {
							logger.Errorf("[engine] add source %s error %s", plugin, err)
						}
					}
				}
			}
			for confKey, _ := range oldPluginData {
				if _, exists := newPluginData[confKey]; !exists {
					logger.Infof("[engine] Delete source %s, key %s", plugin, confKey)
					err := meta.DelSourceConfKey(plugin, confKey, "en_US")
					if err != nil {
						logger.Errorf("[engine] delete source %s error %s", plugin, err)
					}
				}
			}

		}

		for _, plugin := range toDelete {
			logger.Infof("[engine] Delete source plugin: %s", plugin)
			err := meta.ClearSource(plugin, "en_US")
			if err != nil {
				logger.Errorf("[engine] delete source %s error %s", plugin, err)
			}
		}
		// 更新内部数据源配置引用
		e.sourcesConfig.Data = newSourcesConfig.Data
		e.sourcesConfig.LastUpdateTime = newSourcesConfig.LastUpdateTime
		e.Node.LastSourcesTime = e.sourcesConfig.LastUpdateTime
	}
	logger.Infof("[engine] end reload sources")
}

func (e *CoordinatorAgent) reloadSinks() {

}
