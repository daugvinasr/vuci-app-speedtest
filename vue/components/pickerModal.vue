<template>
  <div>
    <a-modal :title="'Select a server for the test:'" v-model="$parent.modalVisibly" :width="700">
      <div style="display: flex; justify-content: center; align-items: center;">
        <a-input-search v-model="searchField" placeholder="Search by country" style="width: 300px; margin-right: 5px;"
          @enter="searchField != '' ? filterData() : null" @search="searchField != '' ? filterData() : null" />
        <a-button type="primary" style="margin-right: 10px;" @click="searchField != '' ? filterData() : null">Search
        </a-button>
      </div>
      <a-table :columns="columns" :data-source="dataToShow" :rowKey="'id'" :pagination="pagination">
        <span slot="action" slot-scope="record, action">
        <a-button type="primary" style="margin-right: 10px;" @click="$parent.specifiedTest(action)">Search</a-button>
        </span>
      </a-table>
      <template #footer>
        <div></div>
      </template>
    </a-modal>
  </div>
</template>

<script>
export default {
  data () {
    return {
      searchField: '',
      pagination: {
        defaultPageSize: 6
      },
      data: [],
      dataToShow: [],
      columns: [
        {
          title: 'Country',
          dataIndex: 'country'
        },
        {
          title: 'City',
          dataIndex: 'city'

        },
        {
          title: 'Provider',
          dataIndex: 'provider'

        },
        {
          title: 'Action',
          dataIndex: 'action',
          scopedSlots: { customRender: 'action' }
        }]
    }
  },
  created () {
    this.getServers()
  },
  methods: {
    filterData () {
      this.dataToShow = []
      this.data.forEach(element => {
        if (element.country.toLowerCase().includes(this.searchField.toLowerCase())) {
          this.dataToShow.push(element)
        }
      })
    },
    async getServers () {
      await this.$rpc.call('coms', 'ReadServers')
        .then(res => {
          this.data = JSON.parse(res.content)
          this.dataToShow = this.data
        })
        .catch(err => {
          console.log(err)
        })
    }
  }
}
</script>
