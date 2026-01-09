import React, { useContext, useRef, useEffect, useState } from "react";
import { MENU_DEFAULT, MENU_MESSAGE, MENU_GALLERY, MENU_MESSAGE_CHATTING } from "../constant/menu";
import MenuContext from "../context/MenuContext";
import {
  MdOutlinePhone,
  MdArrowBackIosNew,
  MdSend,
  MdOutlineCameraAlt,
  MdPhotoLibrary,
  MdMic,
  MdStop,
  MdPlayArrow,
  MdPause,
} from "react-icons/md";
import axios from "axios";
import { useLongPress } from "@uidotdev/usehooks";
import useSound from "use-sound";
import LoadingComponent from "./LoadingComponent";

const MessageChattingComponent = ({ isShow }) => {
  const { setMenu, chatting, setChatting, profile, resolution, setPreviousMenu, setGallerySelectionMode } =
    useContext(MenuContext);
  const messagesEndRef = useRef(null);
  const [message, setMessage] = useState("");
  const [media, setMedia] = useState("");
  const [deleteMessage, setDeleteMessage] = useState(null);
  const [isOpenDelete, setIsOpenDelete] = useState(false);
  const [isTakingPhoto, setIsTakingPhoto] = useState(false);
  
  // Audio recording states
  const [isRecording, setIsRecording] = useState(false);
  const [mediaRecorder, setMediaRecorder] = useState(null);
  const [audioBlob, setAudioBlob] = useState(null);
  const [recordingTime, setRecordingTime] = useState(0);
  const [playingAudio, setPlayingAudio] = useState({});
  const recordingInterval = useRef(null);
  
  // Cache de blobs de áudio para persistir entre navegações
  const [audioBlobCache, setAudioBlobCache] = useState({});

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({
      // behavior: "smooth",
    });
  };

  // Função para limpar cache antigo de áudio (opcional)
  const cleanOldAudioCache = () => {
    try {
      const keys = Object.keys(localStorage);
      const audioKeys = keys.filter(key => key.startsWith('audio_'));
      
      // Manter apenas os últimos 50 áudios
      if (audioKeys.length > 50) {
        const keysToRemove = audioKeys.slice(0, audioKeys.length - 50);
        keysToRemove.forEach(key => {
          localStorage.removeItem(key);
          console.log('[AUDIO CACHE] Removed old cached audio:', key);
        });
      }
    } catch (error) {
      console.error('[AUDIO CACHE] Error cleaning old cache:', error);
    }
  };

  // Limpar cache antigo quando o componente monta
  useEffect(() => {
    cleanOldAudioCache();
  }, []);

  useEffect(() => {
    scrollToBottom();
    console.log('[CHAT DEBUG] Chatting updated:', chatting);
    console.log('[CHAT DEBUG] Chats array:', chatting.chats);
    console.log('[CHAT DEBUG] Is chats array?', Array.isArray(chatting.chats));
  }, [chatting]);

  // Expose function to context for gallery to use
  useEffect(() => {
    if (chatting.conversationid) {
      window.sendMessageFromGallery = async (photoUrl) => {
        console.log('[CHAT] Sending photo from gallery:', photoUrl);
        
        const response = await axios.post("/send-chatting", {
          conversationid: chatting.conversationid,
          message: "",
          media: photoUrl,
          conversation_name: chatting.conversation_name,
          to_citizenid: chatting.citizenid,
          is_group: chatting.is_group,
        });

        if (response.data) {
          console.log('[CHAT] Photo message sent with ID:', response.data);
          const newMessage = {
            time: "just now",
            message: "",
            media: photoUrl,
            sender_citizenid: profile.citizenid,
            id: response.data,
          };
          setChatting((prevChatting) => ({
            ...prevChatting,
            chats: Array.isArray(prevChatting.chats) ? [...prevChatting.chats, newMessage] : [newMessage],
          }));
        }
      };
    }
  }, [chatting.conversationid, profile.citizenid]);

  // Processar mensagens de áudio quando o chat carrega
  useEffect(() => {
    if (chatting.chats && Array.isArray(chatting.chats)) {
      console.log('[AUDIO CACHE] Processing audio messages...');
      
      chatting.chats.forEach(async (message) => {
        if (message.is_audio && message.media) {
          console.log('[AUDIO CACHE] Found audio message:', message.id, message.media);
          
          // Se a URL não é mais válida (não é blob:), tentar recriar
          if (!message.media.startsWith('blob:') && !audioBlobCache[message.id]) {
            console.log('[AUDIO CACHE] Audio URL needs recreation for message:', message.id);
            
            // Tentar carregar do localStorage
            const cachedBase64 = localStorage.getItem(`audio_${message.id}`);
            if (cachedBase64) {
              console.log('[AUDIO CACHE] Found cached audio in localStorage');
              try {
                // Converter base64 de volta para blob
                const response = await fetch(cachedBase64);
                const blob = await response.blob();
                
                // Salvar no cache de runtime
                setAudioBlobCache(prev => ({
                  ...prev,
                  [message.id]: blob
                }));
                
                // Criar nova URL
                const newUrl = URL.createObjectURL(blob);
                
                // Atualizar a mensagem
                setChatting(prevChatting => ({
                  ...prevChatting,
                  chats: prevChatting.chats.map(chat => 
                    chat.id === message.id ? { ...chat, media: newUrl } : chat
                  )
                }));
                
                console.log('[AUDIO CACHE] Recreated audio URL for message:', message.id);
              } catch (error) {
                console.error('[AUDIO CACHE] Error recreating audio:', error);
              }
            }
          }
        }
      });
    }
  }, [chatting.chats]);

  const handleMessage = (e) => {
    const { value } = e.target;
    setMessage(value);
  };

  const sendMessage = async () => {
    if (message.trim() === "") return;
    
    const messageToSend = message;
    setMessage("");

    const response = await axios.post("/send-chatting", {
      conversationid: chatting.conversationid,
      message: messageToSend,
      media: "",
      conversation_name: chatting.conversation_name,
      to_citizenid: chatting.citizenid,
      is_group: chatting.is_group,
    });

    if (response.data) {
      const newMessage = {
        time: "just now",
        message: messageToSend,
        sender_citizenid: profile.citizenid,
        id: response.data,
      };
      setChatting((prevChatting) => ({
        ...prevChatting,
        chats: Array.isArray(prevChatting.chats) ? [...prevChatting.chats, newMessage] : [newMessage],
      }));
    }
  };

  // Audio recording functions
  const startRecording = async () => {
    try {
      console.log('[AUDIO] Requesting microphone access...');
      
      // Verificar se o navegador suporta getUserMedia
      if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
        alert('Seu navegador não suporta gravação de áudio. Use Chrome, Firefox ou Edge.');
        return;
      }

      // Verificar se MediaRecorder é suportado
      if (!window.MediaRecorder) {
        alert('MediaRecorder não é suportado neste navegador.');
        return;
      }

      const stream = await navigator.mediaDevices.getUserMedia({ 
        audio: {
          echoCancellation: true,
          noiseSuppression: true,
          sampleRate: 44100,
          channelCount: 1
        } 
      });
      
      console.log('[AUDIO] Microphone access granted');
      console.log('[AUDIO] Stream tracks:', stream.getTracks());
      
      // Verificar formatos suportados
      const mimeTypes = [
        'audio/webm;codecs=opus',
        'audio/webm',
        'audio/mp4',
        'audio/ogg;codecs=opus',
        'audio/wav'
      ];
      
      let selectedMimeType = '';
      for (const mimeType of mimeTypes) {
        if (MediaRecorder.isTypeSupported(mimeType)) {
          selectedMimeType = mimeType;
          console.log('[AUDIO] Using MIME type:', mimeType);
          break;
        }
      }
      
      if (!selectedMimeType) {
        console.error('[AUDIO] No supported MIME type found');
        selectedMimeType = 'audio/webm'; // Fallback
      }
      
      const recorder = new MediaRecorder(stream, {
        mimeType: selectedMimeType
      });
      
      const chunks = [];
      
      recorder.ondataavailable = (event) => {
        console.log('[AUDIO] Data available:', event.data.size, 'bytes');
        if (event.data.size > 0) {
          chunks.push(event.data);
        }
      };
      
      recorder.onstop = () => {
        console.log('[AUDIO] Recording stopped, creating blob...');
        const blob = new Blob(chunks, { type: selectedMimeType });
        console.log('[AUDIO] Blob created:', blob.size, 'bytes');
        setAudioBlob(blob);
        
        // Parar todas as tracks do stream
        stream.getTracks().forEach(track => {
          track.stop();
          console.log('[AUDIO] Track stopped:', track.kind);
        });
      };
      
      recorder.onerror = (event) => {
        console.error('[AUDIO] Recording error:', event.error);
        alert('Erro na gravação: ' + event.error);
      };
      
      recorder.onstart = () => {
        console.log('[AUDIO] Recording started');
      };
      
      // Iniciar gravação
      recorder.start(1000); // Capturar dados a cada 1 segundo
      setMediaRecorder(recorder);
      setIsRecording(true);
      setRecordingTime(0);
      
      console.log('[AUDIO] MediaRecorder state:', recorder.state);
      
      // Start recording timer
      recordingInterval.current = setInterval(() => {
        setRecordingTime(prev => {
          if (prev >= 60) { // Max 60 seconds
            stopRecording();
            return 60;
          }
          return prev + 1;
        });
      }, 1000);
      
    } catch (error) {
      console.error('[AUDIO] Error accessing microphone:', error);
      
      if (error.name === 'NotAllowedError') {
        alert('Permissão de microfone negada. Por favor, permita o acesso ao microfone e tente novamente.');
      } else if (error.name === 'NotFoundError') {
        alert('Nenhum microfone encontrado. Verifique se há um microfone conectado.');
      } else if (error.name === 'NotReadableError') {
        alert('Microfone está sendo usado por outro aplicativo.');
      } else {
        alert('Erro ao acessar o microfone: ' + error.message);
      }
    }
  };

  const stopRecording = () => {
    console.log('[AUDIO] Stopping recording...');
    if (mediaRecorder && mediaRecorder.state !== 'inactive') {
      console.log('[AUDIO] MediaRecorder state before stop:', mediaRecorder.state);
      mediaRecorder.stop();
    }
    setIsRecording(false);
    if (recordingInterval.current) {
      clearInterval(recordingInterval.current);
    }
  };

  const sendAudioMessage = async () => {
    if (!audioBlob) {
      console.error('[AUDIO] No audio blob to send');
      return;
    }
    
    console.log('[AUDIO] Sending audio message, blob size:', audioBlob.size);
    
    try {
      // Verificar se o blob tem conteúdo
      if (audioBlob.size === 0) {
        alert('Gravação vazia. Tente gravar novamente.');
        return;
      }

      // Convert blob to base64 para enviar ao servidor
      const reader = new FileReader();
      reader.onloadend = async () => {
        const base64Audio = reader.result.split(',')[1];
        console.log('[AUDIO] Base64 length:', base64Audio.length);
        
        const response = await axios.post("/send-audio-message", {
          conversationid: chatting.conversationid,
          audioData: base64Audio,
          duration: recordingTime,
          conversation_name: chatting.conversation_name,
          to_citizenid: chatting.citizenid,
          is_group: chatting.is_group,
        });

        if (response.data) {
          console.log('[AUDIO] Audio message sent successfully');
          
          // Salvar o blob no cache para uso futuro
          const messageId = response.data.messageId;
          setAudioBlobCache(prev => ({
            ...prev,
            [messageId]: audioBlob
          }));
          
          // Salvar também no localStorage para persistir entre sessões
          try {
            const dataUrl = reader.result; // Já temos o data URL do FileReader
            localStorage.setItem(`audio_${messageId}`, dataUrl);
            console.log('[AUDIO CACHE] Saved audio to localStorage');
          } catch (error) {
            console.error('[AUDIO CACHE] Error saving to localStorage:', error);
          }
          
          // Criar URL temporária para o blob
          const tempAudioUrl = URL.createObjectURL(audioBlob);
          console.log('[AUDIO] Created blob URL:', tempAudioUrl);
          
          const newMessage = {
            time: "just now",
            message: "",
            media: tempAudioUrl, // Usar a URL do blob para reprodução
            audio_duration: recordingTime,
            is_audio: true,
            sender_citizenid: profile.citizenid,
            id: messageId,
          };
          setChatting((prevChatting) => ({
            ...prevChatting,
            chats: Array.isArray(prevChatting.chats) ? [...prevChatting.chats, newMessage] : [newMessage],
          }));
        }
        
        // Reset audio states
        setAudioBlob(null);
        setRecordingTime(0);
      };
      
      reader.onerror = (error) => {
        console.error('[AUDIO] FileReader error:', error);
        alert('Erro ao processar áudio gravado.');
      };
      
      reader.readAsDataURL(audioBlob);
    } catch (error) {
      console.error('[AUDIO] Error sending audio:', error);
      alert('Erro ao enviar áudio: ' + error.message);
    }
  };

  const cancelRecording = () => {
    console.log('[AUDIO] Cancelling recording...');
    if (mediaRecorder && mediaRecorder.state !== 'inactive') {
      mediaRecorder.stop();
    }
    setIsRecording(false);
    setAudioBlob(null);
    setRecordingTime(0);
    if (recordingInterval.current) {
      clearInterval(recordingInterval.current);
    }
  };

  // Função para recriar URL de blob a partir do base64 armazenado
  const recreateAudioUrl = async (messageId, originalUrl) => {
    console.log('[AUDIO CACHE] Recreating audio URL for message:', messageId);
    
    // Verificar se já temos o blob no cache de runtime
    if (audioBlobCache[messageId]) {
      console.log('[AUDIO CACHE] Found blob in runtime cache');
      const newUrl = URL.createObjectURL(audioBlobCache[messageId]);
      return newUrl;
    }
    
    // Tentar carregar do localStorage
    const cachedBase64 = localStorage.getItem(`audio_${messageId}`);
    if (cachedBase64) {
      console.log('[AUDIO CACHE] Found cached audio in localStorage');
      try {
        // Converter data URL de volta para blob
        const response = await fetch(cachedBase64);
        const blob = await response.blob();
        
        // Salvar no cache de runtime
        setAudioBlobCache(prev => ({
          ...prev,
          [messageId]: blob
        }));
        
        // Criar nova URL
        const newUrl = URL.createObjectURL(blob);
        console.log('[AUDIO CACHE] Successfully recreated URL:', newUrl);
        return newUrl;
      } catch (error) {
        console.error('[AUDIO CACHE] Error recreating from localStorage:', error);
      }
    }
    
    console.log('[AUDIO CACHE] No cached audio found for message:', messageId);
    return null;
  };

  const toggleAudioPlayback = async (messageId, audioUrl) => {
    console.log('[AUDIO PLAYER] Attempting to play audio:', messageId, audioUrl);
    
    // Verificar se a URL ainda é válida
    if (audioUrl && !audioUrl.startsWith('blob:')) {
      console.log('[AUDIO PLAYER] Invalid blob URL, trying to recreate...');
      const newUrl = await recreateAudioUrl(messageId, audioUrl);
      if (newUrl) {
        audioUrl = newUrl;
        console.log('[AUDIO PLAYER] Recreated URL:', newUrl);
        
        // Atualizar a mensagem com a nova URL
        setChatting(prevChatting => ({
          ...prevChatting,
          chats: prevChatting.chats.map(chat => 
            chat.id === messageId ? { ...chat, media: newUrl } : chat
          )
        }));
      } else {
        console.log('[AUDIO PLAYER] Could not recreate URL');
        alert('Áudio não está mais disponível. Saia e entre novamente na conversa.');
        return;
      }
    }
    
    const audioElement = document.getElementById(`audio-${messageId}`);
    
    if (!audioElement) {
      console.error('[AUDIO PLAYER] Audio element not found for message:', messageId);
      return;
    }
    
    // Atualizar o src do elemento se necessário
    if (audioElement.src !== audioUrl) {
      console.log('[AUDIO PLAYER] Updating audio element src');
      audioElement.src = audioUrl;
    }
    
    console.log('[AUDIO PLAYER] Audio element found, current src:', audioElement.src);
    console.log('[AUDIO PLAYER] Audio element volume:', audioElement.volume);
    console.log('[AUDIO PLAYER] Audio element muted:', audioElement.muted);
    
    if (playingAudio[messageId]) {
      console.log('[AUDIO PLAYER] Pausing audio');
      audioElement.pause();
      setPlayingAudio(prev => ({ ...prev, [messageId]: false }));
    } else {
      // Pause all other audios
      Object.keys(playingAudio).forEach(id => {
        if (id !== messageId.toString()) {
          const otherAudio = document.getElementById(`audio-${id}`);
          if (otherAudio) {
            otherAudio.pause();
            console.log('[AUDIO PLAYER] Paused other audio:', id);
          }
        }
      });
      
      console.log('[AUDIO PLAYER] Starting playback for:', messageId);
      
      // Configurar volume e outras propriedades
      audioElement.volume = 1.0; // Volume máximo
      audioElement.muted = false; // Garantir que não está mutado
      audioElement.currentTime = 0; // Começar do início
      
      console.log('[AUDIO PLAYER] Audio configured - Volume:', audioElement.volume, 'Muted:', audioElement.muted);
      
      setPlayingAudio({ [messageId]: true });
      
      // Verificar se o áudio pode ser reproduzido
      audioElement.oncanplay = () => {
        console.log('[AUDIO PLAYER] Audio can play, duration:', audioElement.duration);
      };
      
      audioElement.oncanplaythrough = () => {
        console.log('[AUDIO PLAYER] Audio can play through without buffering');
      };
      
      audioElement.onplay = () => {
        console.log('[AUDIO PLAYER] Audio play event fired');
      };
      
      audioElement.onplaying = () => {
        console.log('[AUDIO PLAYER] Audio is actually playing');
      };
      
      audioElement.onvolumechange = () => {
        console.log('[AUDIO PLAYER] Volume changed to:', audioElement.volume);
      };
      
      audioElement.onerror = (error) => {
        console.error('[AUDIO PLAYER] Audio error:', error);
        console.error('[AUDIO PLAYER] Audio error details:', audioElement.error);
        setPlayingAudio(prev => ({ ...prev, [messageId]: false }));
        alert('Erro ao reproduzir áudio. Arquivo pode estar corrompido.');
      };
      
      audioElement.onended = () => {
        console.log('[AUDIO PLAYER] Audio ended');
        setPlayingAudio(prev => ({ ...prev, [messageId]: false }));
      };
      
      audioElement.onloadstart = () => {
        console.log('[AUDIO PLAYER] Audio load started');
      };
      
      audioElement.onloadeddata = () => {
        console.log('[AUDIO PLAYER] Audio data loaded');
      };
      
      audioElement.onloadedmetadata = () => {
        console.log('[AUDIO PLAYER] Audio metadata loaded, duration:', audioElement.duration);
      };
      
      // Tentar reproduzir
      const playPromise = audioElement.play();
      
      if (playPromise !== undefined) {
        playPromise
          .then(() => {
            console.log('[AUDIO PLAYER] Playback started successfully');
            console.log('[AUDIO PLAYER] Current time:', audioElement.currentTime);
            console.log('[AUDIO PLAYER] Duration:', audioElement.duration);
            console.log('[AUDIO PLAYER] Paused:', audioElement.paused);
            
            // Verificar se realmente está tocando após um tempo
            setTimeout(() => {
              console.log('[AUDIO PLAYER] After 100ms - Current time:', audioElement.currentTime, 'Paused:', audioElement.paused);
            }, 100);
          })
          .catch(error => {
            console.error('[AUDIO PLAYER] Playback failed:', error);
            setPlayingAudio(prev => ({ ...prev, [messageId]: false }));
            
            if (error.name === 'NotSupportedError') {
              alert('Formato de áudio não suportado pelo navegador.');
            } else if (error.name === 'NotAllowedError') {
              alert('Reprodução de áudio bloqueada. Clique em qualquer lugar da página primeiro.');
            } else {
              alert('Erro ao reproduzir áudio: ' + error.message);
            }
          });
      }
    }
  };

  const formatTime = (seconds) => {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}:${secs.toString().padStart(2, '0')}`;
  };

  // Função para testar o microfone
  const testMicrophone = async () => {
    try {
      console.log('[AUDIO TEST] Testing microphone...');
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      console.log('[AUDIO TEST] Microphone access granted');
      
      // Parar o stream imediatamente
      stream.getTracks().forEach(track => track.stop());
      
      alert('Microfone funcionando! Você pode gravar áudio.');
    } catch (error) {
      console.error('[AUDIO TEST] Microphone test failed:', error);
      alert('Erro no microfone: ' + error.message);
    }
  };

  // Função para testar reprodução de áudio
  const testAudioPlayback = () => {
    console.log('[AUDIO TEST] Testing audio playback...');
    
    // Criar um beep simples para testar
    const audioContext = new (window.AudioContext || window.webkitAudioContext)();
    const oscillator = audioContext.createOscillator();
    const gainNode = audioContext.createGain();
    
    oscillator.connect(gainNode);
    gainNode.connect(audioContext.destination);
    
    oscillator.frequency.setValueAtTime(800, audioContext.currentTime);
    gainNode.gain.setValueAtTime(0.3, audioContext.currentTime);
    
    oscillator.start();
    oscillator.stop(audioContext.currentTime + 0.5);
    
    console.log('[AUDIO TEST] Beep sound should play now');
    alert('Se você ouviu um beep, o áudio está funcionando!');
  };

  function hide() {
    const container = document.getElementById("z-phone-root-frame");
    container.setAttribute("class", "z-phone-fadeout");
    setTimeout(function () {
      container.setAttribute("class", "z-phone-invisible");
    }, 300);
  }

  function show() {
    const container = document.getElementById("z-phone-root-frame");
    container.setAttribute("class", "z-phone-fadein");
    setTimeout(function () {
      container.setAttribute("class", "z-phone-visible");
    }, 300);
  }

  const sendMessageMedia = async () => {
    if (isTakingPhoto) return;
    setIsTakingPhoto(true);
    
    hide();
    await axios.post("/close");
    await axios
      .post("/TakePhoto")
      .then(async function (response) {
        const responseSend = await axios.post("/send-chatting", {
          conversationid: chatting.conversationid,
          message: "",
          media: response.data,
          conversation_name: chatting.conversation_name,
          to_citizenid: chatting.citizenid,
          is_group: chatting.is_group,
        });

        if (responseSend.data) {
          const newMessage = {
            time: "just now",
            message: "",
            media: response.data,
            sender_citizenid: profile.citizenid,
            id: responseSend.data,
          };
          setChatting((prevChatting) => ({
            ...prevChatting,
            chats: Array.isArray(prevChatting.chats) ? [...prevChatting.chats, newMessage] : [newMessage],
          }));
        }
      })
      .catch(function (error) {
        console.log(error);
      })
      .finally(function () {
        setIsTakingPhoto(false);
        show();
      });
  };

  const onPressChat = useLongPress(
    (event) => {
      const data = JSON.parse(event.target.dataset.info);
      if (data) {
        setDeleteMessage(data);
        setIsOpenDelete(true);
      }
    },
    {
      onStart: (event) => console.log("Press started"),
      onFinish: (event) => console.log("Press Finished"),
      onCancel: (event) => console.log("Press cancelled"),
      threshold: 500,
    }
  );

  return (
    <div
      className="relative flex flex-col w-full h-full"
      style={{
        display: isShow ? "block" : "none",
      }}
    >
      <div
        className={`absolute w-full z-20 ${
          isOpenDelete ? "visible" : "invisible"
        }`}
        style={{
          height: resolution.layoutHeight ? resolution.layoutHeight : 0,
          width: resolution.layoutWidth ? resolution.layoutWidth : 0,
          backgroundColor: "rgba(31, 41, 55, 0.8)",
        }}
      >
        <div className="flex flex-col justify-center h-full w-full px-5">
          <div className="flex flex-col space-y-2 bg-slate-600 w-full rounded p-3">
            <span className="text-white text-sm font-semibold">
              Delete message?
            </span>
            <span className="text-white text-sm">
              {deleteMessage?.msg?.message == ""
                ? deleteMessage?.msg?.is_audio ? "Audio message" : "Media"
                : deleteMessage?.msg?.message}
            </span>
            <div className="flex justify-end space-x-4">
              <button
                className="rounded text-sm text-white"
                onClick={() => {
                  setDeleteMessage(null);
                  setIsOpenDelete(false);
                }}
              >
                Cancel
              </button>
              <button
                className="rounded text-sm text-red-500"
                onClick={async () => {
                  const response = await axios.post("/delete-message", {
                    id: deleteMessage?.msg?.id,
                  });

                  if (response.data) {
                    chatting.chats[deleteMessage?.index].is_deleted = true;
                    setChatting((prevChatting) => ({
                      ...prevChatting,
                      chats: Array.isArray(chatting.chats) ? chatting.chats : [],
                    }));
                  }

                  setDeleteMessage(null);
                  setIsOpenDelete(false);
                }}
              >
                Delete
              </button>
            </div>
          </div>
        </div>
      </div>

      {/* Audio Recording Modal */}
      {(isRecording || audioBlob) && (
        <div className="absolute bottom-0 left-0 w-full bg-slate-800 rounded-t-lg pb-8 z-50">
          <div className="flex flex-col space-y-4 px-4 pt-4">
            <div className="flex justify-center">
              <div className="w-1/3 h-1 bg-white rounded-full"></div>
            </div>
            
            {isRecording ? (
              <div className="flex flex-col items-center space-y-4">
                <div className="flex items-center space-x-4">
                  <div className="w-3 h-3 bg-red-500 rounded-full animate-pulse"></div>
                  <span className="text-white text-lg font-mono">
                    {formatTime(recordingTime)}
                  </span>
                </div>
                <div className="text-white text-sm text-center">
                  Gravando áudio... Fale agora!
                </div>
                <div className="flex space-x-4">
                  <button
                    onClick={cancelRecording}
                    className="px-4 py-2 bg-gray-600 rounded-full text-white"
                  >
                    Cancelar
                  </button>
                  <button
                    onClick={stopRecording}
                    className="px-4 py-2 bg-red-600 rounded-full text-white flex items-center space-x-2"
                  >
                    <MdStop />
                    <span>Parar</span>
                  </button>
                </div>
              </div>
            ) : audioBlob && (
              <div className="flex flex-col items-center space-y-4">
                <div className="flex items-center space-x-2">
                  <MdMic className="text-white" />
                  <span className="text-white">
                    Áudio gravado ({formatTime(recordingTime)}) - {Math.round(audioBlob.size / 1024)}KB
                  </span>
                </div>
                <div className="text-white text-sm text-center">
                  {audioBlob.size > 0 ? 'Áudio capturado com sucesso!' : 'Erro: Áudio vazio'}
                </div>
                <div className="flex space-x-4">
                  <button
                    onClick={cancelRecording}
                    className="px-4 py-2 bg-gray-600 rounded-full text-white"
                  >
                    Cancelar
                  </button>
                  <button
                    onClick={sendAudioMessage}
                    disabled={audioBlob.size === 0}
                    className={`px-4 py-2 rounded-full text-white flex items-center space-x-2 ${
                      audioBlob.size > 0 ? 'bg-green-600 hover:bg-green-700' : 'bg-gray-500 cursor-not-allowed'
                    }`}
                  >
                    <MdSend />
                    <span>Enviar</span>
                  </button>
                </div>
              </div>
            )}
          </div>
        </div>
      )}

      {chatting == undefined ? (
        <LoadingComponent />
      ) : (
        <>
          <div className="absolute top-0 flex w-full justify-between py-1.5 bg-black pt-8 z-10">
            <div className="flex items-center px-2 space-x-2 cursor-pointer">
              <div>
                <MdArrowBackIosNew
                  className="text-lg text-blue-500"
                  onClick={() => setMenu(MENU_MESSAGE)}
                />
              </div>

              <img
                src={chatting.avatar}
                className="w-8 h-8 object-cover rounded-full"
                alt=""
                onError={(error) => {
                  error.target.src = "./images/noimage.jpg";
                }}
              />
              <div className="flex flex-col">
                <div className="text-sm text-white line-clamp-1 font-medium">
                  {chatting.conversation_name}
                </div>
                <span className="text-xss font-light text-gray-400">
                  last seen {chatting.last_seen}
                </span>
              </div>
            </div>

            <div>
              {!chatting.is_group ? (
                <div
                  className="flex items-center px-2 text-white cursor-pointer hover:text-green-600"
                  onClick={async () => {
                    try {
                      const response = await axios.post("/start-call", {
                        from_avatar: profile.avatar,
                        from_phone_number: profile.phone_number,
                        to_phone_number: chatting.phone_number,
                      });
                      result = response.data;
                    } catch (error) {
                      console.error("error /start-call", error);
                    }
                  }}
                >
                  <MdOutlinePhone className="text-lg" />
                </div>
              ) : null}
            </div>
          </div>

          <div
            className="flex flex-col w-full h-full text-white overflow-y-auto"
            style={{
              paddingTop: 60,
            }}
          >
            <div className="flex-1 justify-between flex flex-col h-full">
              <div className="no-scrollbar flex flex-col space-y-4 p-3 overflow-y-auto pb-12">
                {chatting.chats && Array.isArray(chatting.chats) &&
                  chatting.chats.map((v, i) => {
                    return !(v.sender_citizenid == profile.citizenid) ? (
                      <div className="flex items-end" key={i}>
                        <div
                          className="relative flex flex-col text-xs items-start"
                          style={{
                            maxWidth: `${resolution.layoutWidth - 50}px`,
                          }}
                        >
                          <span
                            className="pb-4 px-2 py-1.5 rounded-lg inline-block rounded-bl-none bg-[#242527] text-white text-left"
                            style={{
                              minWidth: `100px`,
                            }}
                          >
                            {v.is_deleted ? (
                              <span className="text-gray-200 italic">
                                This message was deleted
                              </span>
                            ) : (
                              <>
                                {v.message == "" ? (
                                  v.is_audio ? (
                                    // Verificar se é uma URL válida para reprodução
                                    v.media && (v.media.startsWith('blob:') || v.media.startsWith('data:')) ? (
                                      <div className="flex items-center space-x-2 min-w-[150px]">
                                        <button
                                          onClick={() => toggleAudioPlayback(v.id, v.media)}
                                          className="flex items-center justify-center w-8 h-8 bg-gray-600 rounded-full hover:bg-gray-500 transition-colors"
                                        >
                                          {playingAudio[v.id] ? (
                                            <MdPause className="text-white text-sm" />
                                          ) : (
                                            <MdPlayArrow className="text-white text-sm" />
                                          )}
                                        </button>
                                        <div className="flex-1">
                                          <div className="w-full bg-gray-600 rounded-full h-1">
                                            <div className="bg-blue-500 h-1 rounded-full w-1/3"></div>
                                          </div>
                                          <div className="flex justify-between items-center mt-1">
                                            <span className="text-xs text-gray-300">
                                              🎤 {v.audio_duration ? formatTime(v.audio_duration) : "0:00"}
                                            </span>
                                            <span className="text-xs text-gray-400">
                                              {playingAudio[v.id] ? 'Reproduzindo...' : 'Clique para ouvir'}
                                            </span>
                                          </div>
                                        </div>
                                        <audio
                                          id={`audio-${v.id}`}
                                          src={v.media}
                                          preload="metadata"
                                          style={{ display: 'none' }}
                                        />
                                      </div>
                                    ) : (
                                      // Mensagem de áudio antiga ou inválida
                                      <div className="flex items-center space-x-2 min-w-[150px] opacity-60">
                                        <div className="flex items-center justify-center w-8 h-8 bg-gray-500 rounded-full">
                                          <MdMic className="text-white text-sm" />
                                        </div>
                                        <div className="flex-1">
                                          <span className="text-xs text-gray-400">
                                            🎤 Mensagem de áudio ({v.audio_duration ? formatTime(v.audio_duration) : "0:00"})
                                          </span>
                                          <div className="text-xs text-gray-500">
                                            Áudio não disponível para reprodução
                                          </div>
                                        </div>
                                      </div>
                                    )
                                  ) : (
                                    <img
                                      className="rounded pb-1"
                                      src={v.media}
                                      alt=""
                                      data-info={JSON.stringify({
                                        msg: v,
                                        index: i,
                                      })}
                                    />
                                  )
                                ) : (
                                  <span
                                    data-info={JSON.stringify({
                                      msg: v,
                                      index: i,
                                    })}
                                  >
                                    {v.message}
                                  </span>
                                )}
                              </>
                            )}
                          </span>
                          <span
                            className="absolute bottom-0 right-1 text-gray-100"
                            style={{
                              fontSize: 10,
                            }}
                          >
                            {v.time}
                          </span>
                        </div>
                      </div>
                    ) : (
                      <div
                        className="flex items-end justify-end"
                        key={i}
                        {...(v.is_deleted || v.minute_diff > 30
                          ? null
                          : onPressChat)}
                      >
                        <div
                          className="relative flex flex-col text-xs items-end"
                          style={{
                            maxWidth: `${resolution.layoutWidth - 50}px`,
                          }}
                        >
                          <div
                            className="pb-4 px-2 py-1.5 rounded-lg inline-block rounded-br-none bg-[#134D37] text-white text-left"
                            style={{
                              minWidth: `100px`,
                            }}
                          >
                            {v.is_deleted ? (
                              <span className="text-gray-200 italic">
                                This message was deleted
                              </span>
                            ) : (
                              <>
                                {v.message == "" ? (
                                  v.is_audio ? (
                                    // Verificar se é uma URL válida para reprodução
                                    v.media && (v.media.startsWith('blob:') || v.media.startsWith('data:')) ? (
                                      <div className="flex items-center space-x-2 min-w-[150px]">
                                        <button
                                          onClick={() => toggleAudioPlayback(v.id, v.media)}
                                          className="flex items-center justify-center w-8 h-8 bg-green-600 rounded-full hover:bg-green-500 transition-colors"
                                        >
                                          {playingAudio[v.id] ? (
                                            <MdPause className="text-white text-sm" />
                                          ) : (
                                            <MdPlayArrow className="text-white text-sm" />
                                          )}
                                        </button>
                                        <div className="flex-1">
                                          <div className="w-full bg-green-600 rounded-full h-1">
                                            <div className="bg-green-300 h-1 rounded-full w-1/3"></div>
                                          </div>
                                          <div className="flex justify-between items-center mt-1">
                                            <span className="text-xs text-gray-300">
                                              🎤 {v.audio_duration ? formatTime(v.audio_duration) : "0:00"}
                                            </span>
                                            <span className="text-xs text-gray-400">
                                              {playingAudio[v.id] ? 'Reproduzindo...' : 'Clique para ouvir'}
                                            </span>
                                          </div>
                                        </div>
                                        <audio
                                          id={`audio-${v.id}`}
                                          src={v.media}
                                          preload="metadata"
                                          style={{ display: 'none' }}
                                        />
                                      </div>
                                    ) : (
                                      // Mensagem de áudio antiga ou inválida
                                      <div className="flex items-center space-x-2 min-w-[150px] opacity-60">
                                        <div className="flex items-center justify-center w-8 h-8 bg-gray-500 rounded-full">
                                          <MdMic className="text-white text-sm" />
                                        </div>
                                        <div className="flex-1">
                                          <span className="text-xs text-gray-400">
                                            🎤 Mensagem de áudio ({v.audio_duration ? formatTime(v.audio_duration) : "0:00"})
                                          </span>
                                          <div className="text-xs text-gray-500">
                                            Áudio não disponível para reprodução
                                          </div>
                                        </div>
                                      </div>
                                    )
                                  ) : (
                                    <img
                                      className="rounded pb-1"
                                      src={v.media}
                                      alt=""
                                      data-info={JSON.stringify({
                                        msg: v,
                                        index: i,
                                      })}
                                    />
                                  )
                                ) : (
                                  <span
                                    data-info={JSON.stringify({
                                      msg: v,
                                      index: i,
                                    })}
                                  >
                                    {v.message}
                                  </span>
                                )}
                              </>
                            )}
                          </div>
                          <span
                            className="absolute bottom-0.5 right-1 text-gray-100"
                            style={{
                              fontSize: 10,
                            }}
                          >
                            {v.time}
                          </span>
                        </div>
                      </div>
                    );
                  })}
                <div ref={messagesEndRef}></div>
              </div>
            </div>
          </div>
          <div className="absolute bottom-0 bg-black flex items-center w-full pb-5 pt-2">
            <div
              className="flex flex-wrap items-center text-white ml-2 mr-1 cursor-pointer"
              onClick={sendMessageMedia}
            >
              <MdOutlineCameraAlt className="text-xl" />
            </div>
            <div
              className="flex flex-wrap items-center text-white mr-2 cursor-pointer"
              onClick={() => {
                setPreviousMenu(MENU_MESSAGE_CHATTING);
                setGallerySelectionMode(true);
                setMenu(MENU_GALLERY);
              }}
            >
              <MdPhotoLibrary className="text-xl" />
            </div>
            <div
              className="flex flex-wrap items-center text-white mr-2 cursor-pointer"
              onClick={isRecording ? stopRecording : startRecording}
            >
              {isRecording ? (
                <MdStop className="text-xl text-red-500" />
              ) : (
                <MdMic className="text-xl" />
              )}
            </div>
            <div className="w-full">
              <input
                type="text"
                placeholder="Type your message..."
                className="w-full text-xs text-white flex-1 border border-gray-700 focus:outline-none rounded-full px-2 py-1 bg-[#3B3B3B]"
                value={message}
                autoComplete="off"
                onChange={handleMessage}
                onKeyPress={(e) => {
                  if (e.key === 'Enter') {
                    e.preventDefault();
                    sendMessage();
                  }
                }}
              />
            </div>
            <div
              onClick={sendMessage}
              className="flex items-center bg-[#33C056] text-black rounded-full p-1.5 ml-2 mr-2 hover:bg-[#134d37] cursor-pointer text-white"
            >
              <MdSend className="text-sm" />
            </div>
          </div>
        </>
      )}
    </div>
  );
};
export default MessageChattingComponent;