<template>
  <div class="container model-list" v-loading="loading">
    <div class="handle-box">
      <el-input v-model="query.name" placeholder="模型名称" class="handle-input" />

      <el-button :icon="Search" @click="fetchData">搜索</el-button>
      <el-button type="primary" :icon="Plus" @click="add">新增</el-button>
    </div>

    <el-row>
      <el-table :data="items" :row-key="(row) => row.id" table-layout="auto">
        <el-table-column type="selection" width="38"></el-table-column>
        <el-table-column prop="name" label="模型名称">
          <template #default="scope">
            <span class="sort" :data-id="scope.row.id">
              <i class="iconfont icon-drag"></i>
              {{ scope.row.name }}
            </span>
          </template>
        </el-table-column>
        <el-table-column prop="type" label="模型类型">
          <template #default="scope">
            <el-tag type="primary" v-if="scope.row.type === 'img'">绘图</el-tag>
            <el-tag type="success" v-else>聊天</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="value" label="模型值">
          <template #default="scope">
            <span>{{ scope.row.value }}</span>
            <el-icon class="copy-model" :data-clipboard-text="scope.row.value">
              <DocumentCopy />
            </el-icon>
          </template>
        </el-table-column>
        <el-table-column prop="power" label="费率" />
        <el-table-column prop="max_tokens" label="最大响应长度" />
        <el-table-column prop="max_context" label="最大上下文长度" />
        <el-table-column prop="temperature" label="创意度" />
        <el-table-column prop="enabled" label="启用状态">
          <template #default="scope">
            <el-switch v-model="scope.row['enabled']" @change="modelSet('enabled', scope.row)" />
          </template>
        </el-table-column>
        <el-table-column prop="enabled" label="开放状态">
          <template #default="scope">
            <el-switch v-model="scope.row['open']" @change="modelSet('open', scope.row)" />
          </template>
        </el-table-column>

        <el-table-column prop="key_name" label="绑定API-KEY" />
        <el-table-column label="操作" width="180">
          <template #default="scope">
            <el-button size="small" type="primary" @click="edit(scope.row)">编辑</el-button>
            <el-popconfirm title="确定要删除当前记录吗?" @confirm="remove(scope.row)" :width="200">
              <template #reference>
                <el-button size="small" type="danger">删除</el-button>
              </template>
            </el-popconfirm>
          </template>
        </el-table-column>
      </el-table>
    </el-row>

    <el-dialog v-model="showDialog" :title="title" :close-on-click-modal="false" style="width: 90%; max-width: 600px">
      <el-form :model="item" label-width="120px" ref="formRef" :rules="rules">
        <el-form-item label="模型类型：" prop="type">
          <el-select v-model="item.type" placeholder="请选择模型类型">
            <el-option v-for="v in type" :value="v.value" :label="v.label" :key="v.value">
              {{ v.label }}
            </el-option>
          </el-select>
        </el-form-item>
        <el-form-item label="模型名称：" prop="name">
          <el-input v-model="item.name" autocomplete="off" />
        </el-form-item>

        <el-form-item label="模型值：" prop="value">
          <el-input v-model="item.value" autocomplete="off" />
        </el-form-item>

        <el-form-item label="消耗算力：" prop="power">
          <template #label>
            <div class="flex items-center">
              <span class="mr-1">消耗算力</span>
              <el-tooltip effect="dark" content="每日签到赠送算力" raw-content placement="right">
                <el-icon>
                  <InfoFilled />
                </el-icon>
              </el-tooltip>
            </div>
          </template>
          <el-input v-model.number="item.power" autocomplete="off" placeholder="消耗算力" />
        </el-form-item>

        <div v-if="item.type === 'chat'">
          <el-form-item label="最长响应：" prop="max_tokens">
            <el-input v-model.number="item.max_tokens" autocomplete="off" placeholder="模型最大响应长度" />
          </el-form-item>

          <el-form-item>
            <template #label>
              <div class="flex items-center">
                <span class="mr-1">最大上下文</span>
                <el-tooltip effect="dark" content="去各大模型的官方 API 文档查询模型支持的最大上下文长度" raw-content placement="right">
                  <el-icon>
                    <InfoFilled />
                  </el-icon>
                </el-tooltip>
              </div>
            </template>
            <el-input v-model.number="item.max_context" autocomplete="off" placeholder="模型最大上下文长度" />
          </el-form-item>

          <el-form-item label="创意度：" prop="temperature">
            <template #label>
              <div class="flex items-center">
                <span class="mr-1">创意度</span>
                <el-tooltip effect="dark" content="OpenAI 0-2，其他模型 0-1" raw-content placement="right">
                  <el-icon>
                    <InfoFilled />
                  </el-icon>
                </el-tooltip>
              </div>
            </template>
            <el-input v-model="item.temperature" autocomplete="off" placeholder="模型创意度" />
          </el-form-item>
        </div>

        <el-form-item label="绑定API-KEY：" prop="apikey">
          <el-select v-model="item.key_id" placeholder="请选择 API KEY" filterable clearable>
            <el-option v-for="v in apiKeys" :value="v.id" :label="v.name" :key="v.id">
              {{ v.name }}
              <el-text type="info" size="small">{{ substr(v.api_url, 50) }}</el-text>
            </el-option>
          </el-select>
        </el-form-item>

        <el-form-item label="启用状态：" prop="enable">
          <el-switch v-model="item.enabled" />
        </el-form-item>
        <el-form-item>
          <template #label>
            <div class="flex items-center">
              <span class="mr-1">开放状态</span>
              <el-tooltip effect="dark" content="开放后，该模型将对所有用户可见。<br/> 如果模型没有启用，则当前设置无效。" raw-content placement="right">
                <el-icon>
                  <InfoFilled />
                </el-icon>
              </el-tooltip>
            </div>
          </template>
          <el-switch v-model="item.open" />
        </el-form-item>
      </el-form>

      <template #footer>
        <span class="dialog-footer">
          <el-button @click="showDialog = false">取消</el-button>
          <el-button type="primary" @click="save">提交</el-button>
        </span>
      </template>
    </el-dialog>
  </div>
</template>

<script setup>
import { onMounted, onUnmounted, reactive, ref } from "vue";
import { httpGet, httpPost } from "@/utils/http";
import { ElMessage } from "element-plus";
import { dateFormat, removeArrayItem, substr } from "@/utils/libs";
import { DocumentCopy, InfoFilled, Plus, Search } from "@element-plus/icons-vue";
import { Sortable } from "sortablejs";
import ClipboardJS from "clipboard";
import Default from "md-editor-v3";

// 变量定义
const items = ref([]);
const query = ref({ name: "" });
const item = ref({});
const showDialog = ref(false);
const title = ref("");
const rules = reactive({
  type: [{ required: true, message: "请选择模型类型", trigger: "change" }],
  name: [{ required: true, message: "请输入模型名称", trigger: "change" }],
  value: [{ required: true, message: "请输入模型值", trigger: "change" }],
  power: [{ required: true, message: "请输入消耗算力", trigger: "change" }],
});
const loading = ref(true);
const formRef = ref(null);
const type = ref([
  { label: "聊天", value: "chat" },
  { label: "绘图", value: "img" },
]);

// 获取 API KEY
const apiKeys = ref([]);
httpGet("/api/admin/apikey/list?type=chat")
  .then((res) => {
    apiKeys.value = res.data;
  })
  .catch((e) => {
    ElMessage.error("获取 API KEY 失败：" + e.message);
  });

// 获取数据
const fetchData = () => {
  httpGet("/api/admin/model/list", query.value)
    .then((res) => {
      if (res.data) {
        // 初始化数据
        const arr = res.data;
        for (let i = 0; i < arr.length; i++) {
          arr[i].last_used_at = dateFormat(arr[i].last_used_at);
        }
        items.value = arr;
      }
      loading.value = false;
    })
    .catch(() => {
      ElMessage.error("获取数据失败");
    });
};

const clipboard = ref(null);
onMounted(() => {
  fetchData();
  const drawBodyWrapper = document.querySelector(".el-table__body tbody");

  // 初始化拖动排序插件
  Sortable.create(drawBodyWrapper, {
    sort: true,
    animation: 500,
    onEnd({ newIndex, oldIndex, from }) {
      if (oldIndex === newIndex) {
        return;
      }

      const sortedData = Array.from(from.children).map((row) => row.querySelector(".sort").getAttribute("data-id"));
      const ids = [];
      const sorts = [];
      sortedData.forEach((id, index) => {
        ids.push(parseInt(id));
        sorts.push(index + 1);
        items.value[index].sort_num = index + 1;
      });

      httpPost("/api/admin/model/sort", { ids: ids, sorts: sorts })
        .then(() => {})
        .catch((e) => {
          ElMessage.error("排序失败：" + e.message);
        });
    },
  });

  clipboard.value = new ClipboardJS(".copy-model");
  clipboard.value.on("success", () => {
    ElMessage.success("复制成功！");
  });

  clipboard.value.on("error", () => {
    ElMessage.error("复制失败！");
  });
});

onUnmounted(() => {
  clipboard.value.destroy();
});

const add = function () {
  title.value = "新增模型";
  showDialog.value = true;
  item.value = { enabled: true, power: 1, open: true, max_tokens: 1024, max_context: 8192, temperature: 0.9 };
};

const edit = function (row) {
  title.value = "修改模型";
  showDialog.value = true;
  item.value = row;
};

const save = function () {
  formRef.value.validate((valid) => {
    item.value.temperature = parseFloat(item.value.temperature);
    if (!item.value.sort_num) {
      item.value.sort_num = items.value.length;
    }
    if (valid) {
      showDialog.value = false;
      item.value.key_id = parseInt(item.value.key_id);
      httpPost("/api/admin/model/save", item.value)
        .then(() => {
          ElMessage.success("操作成功！");
          fetchData();
        })
        .catch((e) => {
          ElMessage.error("操作失败，" + e.message);
        });
    } else {
      return false;
    }
  });
};

const modelSet = (filed, row) => {
  httpPost("/api/admin/model/set", { id: row.id, filed: filed, value: row[filed] })
    .then(() => {
      ElMessage.success("操作成功！");
    })
    .catch((e) => {
      ElMessage.error("操作失败：" + e.message);
    });
};

const remove = function (row) {
  httpGet("/api/admin/model/remove?id=" + row.id)
    .then(() => {
      ElMessage.success("删除成功！");
      items.value = removeArrayItem(items.value, row, (v1, v2) => {
        return v1.id === v2.id;
      });
    })
    .catch((e) => {
      ElMessage.error("删除失败：" + e.message);
    });
};
</script>

<style lang="stylus" scoped>
@import "@/assets/css/admin/form.styl";
.model-list {

  .handle-box {
    margin-bottom 20px
    .handle-input {
      max-width 150px;
      margin-right 10px;
    }
  }

  .cell {
    .copy-model {
      margin-left 6px
      cursor pointer
    }
  }

  .cell {
    .copy-model {
      margin-left 6px
      cursor pointer
    }
  }

  .el-select {
    width: 100%
  }

  .sort {
    cursor move
    .iconfont {
      position relative
      top 1px
    }
  }

  .pagination {
    padding 20px 0
    display flex
    justify-content right
  }

}
</style>
