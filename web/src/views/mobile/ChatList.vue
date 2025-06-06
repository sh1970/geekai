<template>
  <div class="app-background">
    <div class="container mobile-chat-list">
      <van-nav-bar
          :title="title"
          left-text="新建会话"
          @click-left="showPicker = true"
          custom-class="navbar"
      >
        <template #right>
          <van-icon name="delete-o" @click="clearAllChatHistory"/>
        </template>
      </van-nav-bar>

      <div class="content">
        <van-search
            v-model="chatName"
            input-align="center"
            placeholder="请输入会话标题"
            custom-class="van-search"
            @input="search"
        />

        <van-list
            v-model:error="error"
            v-model:loading="loading"
            :finished="finished"
            error-text="请求失败，点击重新加载"
            finished-text="没有更多了"
            @load="onLoad"
        >
          <van-swipe-cell v-for="item in chats" :key="item.id">
            <van-cell @click="changeChat(item)">
              <div class="chat-list-item">
                <van-image
                    :src="item.icon"
                    round
                />
                <div class="van-ellipsis">{{ item.title }}</div>
              </div>
            </van-cell>
            <template #right>
              <van-button square text="修改" type="primary" @click="editChat(item)"/>
              <van-button square text="删除" type="danger" @click="removeChat(item)"/>
            </template>
          </van-swipe-cell>
        </van-list>
      </div>
    </div>

    <van-popup v-model:show="showPicker" position="bottom" class="popup">
      <van-picker
          :columns="columns"
          title="选择模型和角色"
          @cancel="showPicker = false"
          @confirm="newChat"
      >
        <template #option="item">
          <div class="picker-option">
            <van-image
                v-if="item.icon"
                :src="item.icon"
                fit="cover"
                round
            />
            <span>{{ item.text }}</span>
          </div>
        </template>
      </van-picker>
    </van-popup>

    <van-dialog v-model:show="showEditChat" title="修改对话标题" show-cancel-button class="dialog" @confirm="saveTitle">
      <van-field v-model="tmpChatTitle" label="" placeholder="请输入对话标题" class="field"/>
    </van-dialog>

  </div>
</template>

<script setup>
import {ref} from "vue";
import {httpGet, httpPost} from "@/utils/http";
import {showConfirmDialog, showFailToast, showSuccessToast} from "vant";
import {checkSession} from "@/store/cache";
import {router} from "@/router";
import {removeArrayItem, showLoginDialog} from "@/utils/libs";

const title = ref("会话列表")
const chatName = ref("")
const chats = ref([])
const allChats = ref([])
const loading = ref(false)
const finished = ref(false)
const error = ref(false)
const loginUser = ref(null)
const isLogin = ref(false)
const roles = ref([])
const models = ref([])
const showPicker = ref(false)
const columns = ref([roles.value, models.value])
const showEditChat = ref(false)
const item = ref({})
const tmpChatTitle = ref("")

checkSession().then((user) => {
  loginUser.value = user
  isLogin.value = true
  // 加载角色列表
  httpGet(`/api/app/list/user`).then((res) => {
    if (res.data) {
      const items = res.data
      for (let i = 0; i < items.length; i++) {
        // console.log(items[i])
        roles.value.push({
          text: items[i].name,
          value: items[i].id,
          icon: items[i].icon,
          helloMsg: items[i].hello_msg
        })
      }
    }
  }).catch(() => {
    showFailToast("加载聊天角色失败")
  })

  // 加载模型
  httpGet('/api/model/list?enable=1').then(res => {
    if (res.data) {
      const items = res.data
      for (let i = 0; i < items.length; i++) {
        models.value.push({text: items[i].name, value: items[i].id})
      }
    }
  }).catch(e => {
    showFailToast("加载模型失败: " + e.message)
  })

}).catch(() => {
  loading.value = false
  finished.value = true

  // 加载角色列表
  httpGet('/api/app/list/user').then((res) => {
    if (res.data) {
      const items = res.data
      for (let i = 0; i < items.length; i++) {
        // console.log(items[i])
        roles.value.push({
          text: items[i].name,
          value: items[i].id,
          icon: items[i].icon,
          helloMsg: items[i].hello_msg
        })
      }
    }
  }).catch(() => {
    showFailToast("加载聊天角色失败")
  })

  // 加载模型
  httpGet('/api/model/list').then(res => {
    if (res.data) {
      const items = res.data
      for (let i = 0; i < items.length; i++) {
        models.value.push({text: items[i].name, value: items[i].id})
      }
    }
  }).catch(e => {
    showFailToast("加载模型失败: " + e.message)
  })
})

const onLoad = () => {
  checkSession().then((user) => {
    httpGet("/api/chat/list?user_id=" + user.id).then((res) => {
      if (res.data) {
        chats.value = res.data;
        allChats.value = res.data;
        finished.value = true
      }
      loading.value = false;
    }).catch(() => {
      error.value = true
      showFailToast("加载会话列表失败")
    })
  }).catch(() => {
    finished.value = true
  })
};

const search = () => {
  if (chatName.value === '') {
    chats.value = allChats.value
    return
  }
  const items = [];
  for (let i = 0; i < allChats.value.length; i++) {
    if (allChats.value[i].title.toLowerCase().indexOf(chatName.value.toLowerCase()) !== -1) {
      items.push(allChats.value[i]);
    }
  }
  chats.value = items;
}

const clearAllChatHistory = () => {
  if (!isLogin.value) {
    return showLoginDialog(router)
  }

  showConfirmDialog({
    title: '操作提示',
    message: '确定要删除所有的会话记录吗？'
  }).then(() => {
    httpGet("/api/chat/clear").then(() => {
      showSuccessToast('所有聊天记录已清空')
      chats.value = [];
    }).catch(e => {
      showFailToast("操作失败：" + e.message)
    })
  }).catch(() => {
    // on cancel
  })
}

const newChat = (item) => {
  if (!isLogin.value) {
    return showLoginDialog(router)
  }
  showPicker.value = false
  const options = item.selectedOptions
  router.push(`/mobile/chat/session?title=新对话&role_id=${options[0].value}&model_id=${options[1].value}`)
}

const changeChat = (chat) => {
  router.push(`/mobile/chat/session?chat_id=${chat.chat_id}`)
}

const editChat = (row) => {
  showEditChat.value = true
  item.value = row
  tmpChatTitle.value = row.title
}
const saveTitle = () => {
  httpPost('/api/chat/update', {chat_id: item.value.chat_id, title: tmpChatTitle.value}).then(() => {
    showSuccessToast("操作成功！");
    item.value.title = tmpChatTitle.value;
  }).catch(e => {
    showFailToast("操作失败：" + e.message);
  })
}

const removeChat = (item) => {
  httpGet('/api/chat/remove?chat_id=' + item.chat_id).then(() => {
    chats.value = removeArrayItem(chats.value, item, function (e1, e2) {
      return e1.id === e2.id
    })
  }).catch(e => {
    showFailToast('操作失败：' + e.message);
  })

}

</script>

<style lang="stylus" scoped>
@import "@/assets/css/mobile/chat-list.styl"
</style>