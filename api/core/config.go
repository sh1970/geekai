package core

// * +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// * Copyright 2023 The Geek-AI Authors. All rights reserved.
// * Use of this source code is governed by a Apache-2.0 license
// * that can be found in the LICENSE file.
// * @Author yangjian102621@163.com
// * +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

import (
	"bytes"
	"geekai/core/types"
	logger2 "geekai/logger"
	"geekai/utils"
	"os"

	"github.com/BurntSushi/toml"
)

var logger = logger2.GetLogger()

func NewDefaultConfig() *types.AppConfig {
	return &types.AppConfig{
		Listen:    "0.0.0.0:5678",
		ProxyURL:  "",
		StaticDir: "./static",
		StaticUrl: "http://localhost/5678/static",
		Redis:     types.RedisConfig{Host: "localhost", Port: 6379, Password: ""},
		Session: types.Session{
			SecretKey: utils.RandString(64),
			MaxAge:    86400,
		},
		ApiConfig: types.ApiConfig{},
		OSS: types.OSSConfig{
			Active: "local",
			Local: types.LocalStorageConfig{
				BaseURL:  "http://localhost/5678/static/upload",
				BasePath: "./static/upload",
			},
		},
		AlipayConfig: types.AlipayConfig{Enabled: false, SandBox: false},
	}
}

func LoadConfig(configFile string) (*types.AppConfig, error) {
	var config *types.AppConfig
	_, err := os.Stat(configFile)
	if err != nil {
		logger.Info("creating new config file: ", configFile)
		config = NewDefaultConfig()
		config.Path = configFile
		// save config
		err := SaveConfig(config)
		if err != nil {
			return nil, err
		}

		return config, nil
	}
	_, err = toml.DecodeFile(configFile, &config)
	if err != nil {
		return nil, err
	}

	return config, err
}

func SaveConfig(config *types.AppConfig) error {
	buf := new(bytes.Buffer)
	encoder := toml.NewEncoder(buf)
	if err := encoder.Encode(&config); err != nil {
		return err
	}

	return os.WriteFile(config.Path, buf.Bytes(), 0644)
}
