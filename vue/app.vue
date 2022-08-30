<template>
  <div>
    <div style="display: flex; justify-content: center; align-items: center;">
      <div style="display: flex; justify-content: center; align-items: center;">
        <i class="bi bi-geo-alt-fill" style="margin-right: 20px; font-size:xx-large;"></i>
        <h1 v-text="country" style="margin-right: 20px"></h1>
      </div>
      <div style="display: flex; justify-content: center; align-items: center;">
        <i class="bi bi-server" style="margin-right: 20px; font-size:xx-large"></i>
        <h1 v-text="provider" style="margin-right: 20px"></h1>
      </div>
      <div style="display: flex; justify-content: center; align-items: center;">
        <i class="bi bi-cloud-arrow-down-fill" style="margin-right: 20px; font-size:xx-large"></i>
        <h1 v-if="lastDownload == '-'" v-text="lastDownload" style="margin-right: 20px"></h1>
        <h1 v-else v-text="lastDownload + ' mbps'" style="margin-right: 20px"></h1>
      </div>
      <div style="display: flex; justify-content: center; align-items: center;">
        <i class="bi bi-cloud-arrow-up-fill" style="margin-right: 20px; font-size:xx-large"></i>
        <h1 v-if="lastUpload == '-'" v-text="lastUpload" style="margin-right: 20px"></h1>
        <h1 v-else v-text="lastUpload + ' mbps'" style="margin-right: 20px"></h1>
      </div>
    </div>

    <div style="display: flex; justify-content: center; align-items: center;">
      <gauge :min="0" :max="100" :value="speed" :valueToExceedLimits="true" activeFill="#2d8cf0" :inactiveFill="'gray'"
        unit="Mbps" :pointerGap="0" />
    </div>
    <div style="display: flex; justify-content: center; align-items: center;">
      <h1 v-text="status"></h1>
    </div>
    <div style="display: flex; justify-content: center; align-items: center;">
      <a-button :disabled="buttonStatus" type="primary" style="margin-right: 10px;" @click="automaticTest()">Start</a-button>
      <a-button :disabled="buttonStatus" type="primary" style="margin-right: 10px;" @click="modalVisibly = true">Select Server</a-button>
    </div>
    <PickerModal></PickerModal>
  </div>

</template>

<script>
import PickerModal from './components/pickerModal.vue'

export default {
  components: { PickerModal },
  data () {
    return {
      speed: 0,
      lastDownload: '-',
      lastUpload: '-',
      status: 'Ready',
      provider: '-',
      modalVisibly: false,
      country: '-',
      buttonStatus: false
    }
  },
  mounted () {
    this.findCountry()
  },
  methods: {
    sleep (milliseconds) {
      const date = Date.now()
      let currentDate = null
      do {
        currentDate = Date.now()
      } while (currentDate - date < milliseconds)
    },
    async findCountry () {
      await this.$rpc.call('coms', 'FindCountry')
        .then(res => {
          this.country = res.content
        })
        .catch(_err => {
          this.status = 'Unable to detect user location'
        })
    },
    async startAutomaticTest () {
      await this.$rpc.call('coms', 'StartAutomaticTest')
        .then(_res => {
          this.status = 'Initiating the speed test'
        })
        .catch(_err => {
          this.status = 'Speed test failed, please try running the test again'
        })
    },
    async startSpecifiedTest (data) {
      await this.$rpc.call('coms', 'StartSpecifiedTest', { host: data.host, provider: data.provider })
        .then(_res => {
          this.status = 'Initiating the speed test'
        })
        .catch(_err => {
          this.status = 'Speed test failed, please try running the test again'
        })
    },
    async readResult () {
      var run = true
      while (run) {
        await this.$rpc.call('coms', 'ReadResult')
          .then(res => {
            if (res.content != null) {
              const content = JSON.parse(res.content)
              this.provider = content.provider
              // Downloading - 1
              // Uploading - 2
              // Finished download - 3
              // Finished upload - 4
              // Finished - 5
              // Searching for the best server - 6
              // Failed - anything else
              switch (content.status) {
                case 1:
                  this.speed = content.downloadSpeed
                  this.status = 'Downloading'
                  break
                case 2:
                  this.speed = content.uploadSpeed
                  this.status = 'Uploading'
                  break
                case 3:
                  this.speed = 0
                  this.status = 'Finished download'
                  break
                case 4:
                  this.speed = 0
                  this.status = 'Finished upload'
                  break
                case 5:
                  this.lastDownload = content.downloadSpeed
                  this.lastUpload = content.uploadSpeed
                  this.status = 'Finished'
                  run = false
                  break
                case 6:
                  this.status = 'Searching for the best server'
                  break
                default:
                  this.lastDownload = 0
                  this.lastUpload = 0
                  this.status = 'Test failed, please try again'
                  run = false
              }
            }
          })
          .catch(_err => {
            this.status = 'Could not read results from the router, please try running the test again'
          })
        this.sleep(500)
      }
    },
    async automaticTest () {
      this.buttonStatus = true
      this.lastDownload = '-'
      this.lastUpload = '-'
      this.provider = '-'
      this.speed = 0
      this.status = 'Preparing for the speed test'
      await this.startAutomaticTest()
      this.sleep(500)
      await this.readResult()
      this.speed = 0
      this.buttonStatus = false
    },
    async specifiedTest (data) {
      this.buttonStatus = true
      this.modalVisibly = false
      this.lastDownload = '-'
      this.lastUpload = '-'
      this.speed = 0
      this.provider = data.provider
      this.status = 'Preparing for the speed test'
      await this.startSpecifiedTest(data)
      this.sleep(500)
      await this.readResult()
      this.speed = 0
      this.buttonStatus = false
    }
  }
}
</script>

<style>
@import url("https://cdn.jsdelivr.net/npm/bootstrap-icons@1.9.1/font/bootstrap-icons.css");
</style>
