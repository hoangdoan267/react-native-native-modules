/* @flow */

import React, { Component } from 'react'
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  Image,
  NativeModules,
  Alert,
  DeviceEventEmitter,
  Platform
} from 'react-native'
import ChannelList from './ChannelList'
import RadioModal from '../components/RadioModal'
import AboutModal from '../components/AboutModal'
import { connect } from 'react-redux'
import { getListChannelByCountry } from '../libs/RequestHelpers'
import { changeInit, changeVersion, increaseTime } from '../actions/AppActions'
import { getChannelList, addToFavorite } from '../actions/ChannelActions'
import { changeStatus, playingChannel } from '../actions/PlayerActions'
import * as TimerActions from '../actions/TimerActions'
import Spinner from 'react-native-spinkit'
import { COLOR_DATA } from '../constants/constants'
import ChannelData from '../data.json'
var StreamingPlayer = NativeModules.StreamingPlayer
import * as StoreReview from 'react-native-store-review'
import BasePlayer from '../components/BasePlayer'

class Home extends BasePlayer {
  constructor(props) {
    super(props)
    this.state = {
      isModal: false,
      isAboutModal: false,
      isChecking: true,
      isCorrupt: false
    }
  }

  componentDidMount() {
    this.props.playerState.tracker.trackScreenView('Home')
    if (Platform.OS === 'ios') {
      this.props.playerState.playerControl.configureAudioSession()
      this.props.playerState.playerControl.configureRemoteControl()
    }
    // this.props.playerState.playerControl.configureAudioSession()
    // this.props.playerState.playerControl.configureRemoteControl()
    this.checkInit()
    this.requestReview()
  }

  componentWillMount() {
    DeviceEventEmitter.addListener('StreamingPlayer', this.handleMediaControl)
  }

  componentWillUnmount() {
    DeviceEventEmitter.removeListener(
      'StreamingPlayer',
      this.handleMediaControl
    )
  }

  handleMediaControl = event => {
    let { dispatch } = this.props
    console.log('event: ' + event.name)
    switch (event.name) {
      case 'play':
        dispatch(changeStatus('playing'))
        break
      case 'pause':
        console.log('Hello')
        dispatch(changeStatus('pause'))
        break
      case 'loading':
        console.log('loading')
        dispatch(changeStatus('loading'))
        break
      case 'network':
        console.log('Network Error')
        dispatch(changeStatus('replay'))
        break
      case 'error':
        dispatch(changeStatus('replay'))
        Alert.alert(
          'Error',
          'Error Channel',
          [
            {
              text: 'OK',
              onPress: () => console.log('Cancel Pressed'),
              style: 'cancel'
            }
          ],
          { cancelable: false }
        )
        break
      case 'timer':
        console.log('timer')
        dispatch(TimerActions.getTimeString(event.seconds))
        break
      case 'timerNoti':
        dispatch(TimerActions.resetTimer())
        break
      default:
    }
  }

  toggleModal = () => {
    if (this.state.isModal == false) {
      this.props.playerState.tracker.trackScreenView('Select Chanel')
    } else {
      this.props.playerState.tracker.trackScreenView('Home')
    }
    this.setState({
      isModal: !this.state.isModal
    })
    let playingIndex = this.props.playerState.playerIndex
    let foundIn = this.props.channel.findIndex(function(el) {
      return el.id == playingIndex
    })
    if (foundIn != -1) {
      if (this.props.channel[foundIn].status == false && foundIn != -1) {
        this.props.playerState.playerControl.pause()
      }
    }
  }

  toggleAboutModal = () => {
    if (this.state.isAboutModal == false) {
      this.props.playerState.tracker.trackScreenView('More')
    } else {
      this.props.playerState.tracker.trackScreenView('Home')
    }
    this.setState({
      isAboutModal: !this.state.isAboutModal
    })
  }

  requestReview = () => {
    let { dispatch } = this.props
    let timeApp = this.props.appState.time + 1
    dispatch(increaseTime(timeApp))
    if (this.props.appState.time == 2 || this.props.appState.time % 5 == 0) {
      if (StoreReview.isAvailable) {
        StoreReview.requestReview()
      }
    }
  }

  renderListButton = () => {
    if (!this.state.isModal && !this.state.isAboutModal) {
      return (
        <TouchableOpacity onPress={() => this.toggleModal()}>
          <Image
            source={{ uri: 'ic_listcard' }}
            style={{ width: 36, height: 36 }}
          />
        </TouchableOpacity>
      )
    }
  }

  renderInit = () => {
    if (this.props.appState.init) {
      return (
        <View
          style={{ flex: 0.5, alignItems: 'center', justifyContent: 'center' }}
        >
          <Spinner
            type={Platform.OS == 'ios' ? 'Arc' : 'WanderingCubes'}
            size={50}
            color="#4a4a4a"
          />
          <Text style={{ color: '#4a4a4a', padding: 10 }}>
            Khởi tạo danh sách kênh ...
          </Text>
        </View>
      )
    } else if (this.state.isChecking) {
      return (
        <View
          style={{ flex: 0.5, alignItems: 'center', justifyContent: 'center' }}
        >
          <Spinner
            type={Platform.OS == 'ios' ? 'Arc' : 'WanderingCubes'}
            size={50}
            color="#4a4a4a"
          />
          <Text style={{ color: '#4a4a4a', padding: 10 }}>
            Cập nhật ...
          </Text>
        </View>
      )
    }
    return <ChannelList player={StreamingPlayer} />
  }

  checkInit = () => {
    let { dispatch } = this.props
    if (this.props.appState.init) {
      let radioList = []
      let data = ChannelData.data
      for (let i = 0; i < data.length; i++) {
        let channelItem = data[i]
        channelItem.color = COLOR_DATA[i % COLOR_DATA.length]
        channelItem.status = true
        channelItem.favorite = false
        channelItem.lastIndex = i
        radioList.push(channelItem)
      }
      dispatch(getChannelList(radioList))
      dispatch(changeInit(false))
      dispatch(changeVersion(data.version))
      this.setState({
        isChecking: false
      })
    } else {
      if (this.props.appState.version != ChannelData.version) {
        this.fetchData()
      } else {
        this.setState({
          isChecking: false
        })
      }
    }
  }

  fetchData = () => {
    let { dispatch } = this.props
    let that = this
    let radioList = ChannelData.data
    let oldList = this.props.channel
    let favoriteOldList = []

    for (let i = 0; i < oldList.length; i++) {
      if (oldList[i].favorite == true) {
        favoriteOldList.push(oldList[i].id)
      }
    }

    for (let i = 0; i < radioList.length; i++) {
      let channelItem = radioList[i]
      channelItem.color = COLOR_DATA[i % COLOR_DATA.length]
      channelItem.status = true
      channelItem.favorite = false
      channelItem.lastIndex = i
      for (let j = oldList.length - 1; j > 0; j--) {
        let oldItem = oldList[j]
        if (oldItem.id == channelItem.id) {
          channelItem.status = oldItem.status
        }
      }
    }

    dispatch(getChannelList(radioList))
    dispatch(changeVersion(ChannelData.version))

    setTimeout(() => {
      let newList = this.props.channel
      for (let i = favoriteOldList.length - 1; i >= 0; i--) {
        console.log(favoriteOldList[i])
        let foundIndex = newList.findIndex(function(el) {
          return el.id === favoriteOldList[i]
        })

        console.log(foundIndex)
        if (foundIndex != -1) {
          dispatch(addToFavorite(newList[foundIndex]))
        }
      }
      this.setState({
        isChecking: false
      })
    }, 200)
  }

  render() {
    return (
      <View style={styles.container}>
        <View
          style={{
            flex: 0.2,
            flexDirection: 'row',
            justifyContent: 'space-between',
            paddingHorizontal: 20,
            alignItems: 'center'
          }}
        >
          <Text
            style={{
              fontFamily: 'SF UI Display',
              color: '#4a4a4a',
              fontSize: 28
            }}
          >
            TEA RADIO
          </Text>
          <TouchableOpacity onPress={() => this.toggleAboutModal()}>
            <Image
              source={{ uri: 'ic_setting' }}
              style={{ width: 24, height: 24 }}
            />
          </TouchableOpacity>
        </View>
        {this.renderInit()}
        <View
          style={{ flex: 0.15, alignItems: 'center', justifyContent: 'center' }}
        >
          {this.renderListButton()}
        </View>
        <RadioModal
          channelList={this.props.channel}
          isVisible={this.state.isModal}
          toogle={this.toggleModal}
        />
        <AboutModal
          isVisible={this.state.isAboutModal}
          toogle={this.toggleAboutModal}
        />
      </View>
    )
  }
}

const mapStateToProps = state => ({
  playerState: state.playerState,
  timerState: state.timerState,
  appState: state.appState,
  channel: state.channelState.channelList
})

export default connect(mapStateToProps)(Home)

const styles = StyleSheet.create({
  container: {
    flex: 1
  }
})
