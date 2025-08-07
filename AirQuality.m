function air_quality_sound_app
    API_KEY = '4c4780a81939ec881e8d969c643380ca';
    bgColor = [0.95 0.95 1];
    accentColor = [0.2 0.4 0.8];
    fig = uifigure('Name','🌫️ Hava Kalitesi Ses Sentezleyici','Position',[500 200 450 580],'Color',bgColor);
    uilabel(fig, 'Text', '🔊 Hava Kalitesi Tabanlı Ses Sentezleyici', ...
        'FontSize', 16, 'FontWeight', 'bold', 'Position', [30 530 400 30], ...
        'FontColor', accentColor);
    uilabel(fig,'Position',[30 490 100 22],'Text','Şehir Adı:','FontWeight','bold');
    cityEdit = uieditfield(fig,'text','Position',[120 490 200 22]);
    uilabel(fig, 'Text', '📋 Hava Kalitesi Verileri', ...
        'FontSize', 14, 'FontWeight', 'bold', 'FontColor', accentColor, ...
        'Position', [30 450 300 22]);
    pm25Label = uilabel(fig,'Position',[30 420 300 22],'Text','PM2.5: -','FontSize', 12);
    no2Label = uilabel(fig,'Position',[30 395 300 22],'Text','NO₂: -','FontSize', 12);
    coLabel = uilabel(fig,'Position',[30 370 300 22],'Text','CO: -','FontSize', 12);
    uilabel(fig, 'Text', '🎛️ Kontroller', ...
        'FontSize', 14, 'FontWeight', 'bold', 'FontColor', accentColor, ...
        'Position', [30 330 300 22]);
    checkBtn = uibutton(fig,'push','Text','Hava Kalitesini Al',...
        'Position',[30 300 170 30],'FontWeight','bold',...
        'BackgroundColor',accentColor,'FontColor','w',...
        'ButtonPushedFcn',@(btn,event) checkAirQuality());
    playBtn = uibutton(fig, 'push', ...
        'Text', 'Sesi Çal', ...
        'Position', [230 300 100 30], ...
        'FontWeight', 'bold', ...
        'BackgroundColor', [0.1 0.6 0.1], ...
        'FontColor', 'w', ...
        'ButtonPushedFcn', @(~,~) playSound());
    plotWaveBtn = uibutton(fig,'push','Text','📈 Dalgayı Görselleştir',...
        'Position',[30 260 170 30],'ButtonPushedFcn',@(btn,event) plotWaveform());
    plotSpecBtn = uibutton(fig,'push','Text','📊 Spektrumu Analiz Et',...
        'Position',[230 260 170 30],'ButtonPushedFcn',@(btn,event) plotSpectrum());
    ax = uiaxes(fig, 'Position', [30 20 390 220], ...
        'Visible', 'off', 'Box', 'on', 'BackgroundColor','w');
    global wavData sampleRate;
    wavData = [];
    sampleRate = 44100;

    function [lat, lon] = getCoordinates(city, key)
        url = sprintf('http://api.openweathermap.org/geo/1.0/direct?q=%s&limit=1&appid=%s', city, key);
        options = weboptions('Timeout', 10);
        try
            data = webread(url, options);
            lat = data(1).lat;
            lon = data(1).lon;
        catch
            lat = []; lon = [];
        end
    end

    function components = fetchAirQuality(lat, lon, key)
        url = sprintf('http://api.openweathermap.org/data/2.5/air_pollution?lat=%.6f&lon=%.6f&appid=%s', lat, lon, key);
        options = weboptions('Timeout', 10);
        try
            data = webread(url, options);
            components = data.list(1).components;
        catch
            components = [];
        end
    end

    function checkAirQuality()
        city = cityEdit.Value;
        if isempty(city)
            uialert(fig,'Lütfen bir şehir adı girin.','Hata');
            return;
        end
        [lat, lon] = getCoordinates(city, API_KEY);
        if isempty(lat)
            uialert(fig,'Şehir bulunamadı.','Hata');
            return;
        end
        components = fetchAirQuality(lat, lon, API_KEY);
        if isempty(components)
            uialert(fig,'Veri alınamadı.','Hata');
            return;
        end
        if isfield(components, 'pm2_5')
            pm25Label.Text = sprintf('PM 2.5: %.2f µg/m³', components.pm2_5);
        else
            pm25Label.Text = 'PM2.5 verisi yok.';
        end
        if isfield(components, 'no2')
            no2Label.Text = sprintf('NO2: %.2f µg/m³', components.no2);
        end
        if isfield(components, 'co')
            coLabel.Text = sprintf('CO: %.2f µg/m³', components.co);
        end
        % Ses üret
        [wavData, sampleRate] = generateSound(components.pm2_5, components.co);
    end

    function [output, fs] = generateSound(pm25, co)
        fs = 44100;
        duration = 5;
        t = linspace(0, duration, fs * duration);
        noise = randn(1, length(t));
    
        env = adsrEnv(0.1, 0.2, 0.6, 0.5, fs, duration); % default env
        raw_sound = noise;
        b = 1; a = 1;
        volume = 0.5;
    
        if pm25 <= 12 && co <= 500 %temiz
            env = adsrEnv(0.1, 0.2, 4, 0.4, fs, duration);
            tone1 = sin(2*pi*440*t);
            tone2 = 0.5*sin(2*pi*660*t);
            tone3 = 0.3*sin(2*pi*880*t);
            chirp = sin(2*pi*(1000 + 200*sin(2*pi*5*t)).*t) .* sin(2*pi*12*t);
            wind = filter(butter(4, 1000 / (fs / 2), 'low'), 1, randn(size(t))) * 0.02;
            mix = tone1 + tone2 + tone3 + chirp*0.8 + wind;
            raw_sound = mix;
            volume = 0.6;
    
        elseif pm25 <= 35 && co <= 1000 %orta
            base_wave = sin(2 * pi * 400 * t);
            mod_wave = square(2 * pi * 50 * t); 
            raw_sound = (base_wave + 0.3 * mod_wave + 0.2 * noise);
            [b, a] = butter(4, [300 700] / (fs / 2), 'bandpass');
            volume = 0.5;
    
        elseif pm25 <= 55 && co <= 3000 %kirli 
            saw = sawtooth(2 * pi * 300 * t);
            raw_sound = (saw + 0.5 * noise);
            [b, a] = butter(4, [200 1200] / (fs / 2), 'bandpass');
            volume = 0.8;
    
        else %zehirli
            env = adsrEnv(0.4, 0.4, 2, 1, fs, duration);
            mod = sin(2*pi*6*t);
            modulated_signal = sin(2*pi*400*t + 100*mod);
            siren = sin(2*pi*(500 + 200*sin(2*pi*0.8*t)).*t);
            harsh = tanh(2 * (modulated_signal + 0.5*siren));
            raw_sound = harsh;
            volume = 1.0;
        end
    
        filtered = filter(b, a, raw_sound);
        output = filtered .* env * volume;
        output = output / max(abs(output));  % normalize
    
        % Nested ADSR function
        function env = adsrEnv(a, d, s, r, fs, duration)
            aS = round(a * fs);
            dS = round(d * fs);
            rS = round(r * fs);
            sS = fs * duration - (aS + dS + rS);
            env = [linspace(0, 1, aS), ...
                   linspace(1, s, dS), ...
                   s * ones(1, sS), ...
                   linspace(s, 0, rS)];
        end
        
    end 
 
    function playSound()
        if isempty(wavData)
            uialert(fig,'Önce veri alınmalıdır.','Uyarı');
            return;
        end
        sound(wavData, sampleRate);
   end
    
   function plotWaveform()
        if isempty(wavData)
            uialert(fig,'Önce veri alınmalıdır.','Uyarı');
            return;
        end
        ax.Visible = 'on';
        cla(ax); % önceki grafiği temizle
        plot(ax, (1:length(wavData))/sampleRate, wavData, 'Color', accentColor);
        xlim(ax, [0 0.05]);
        title(ax, 'Dalga Formu');
        xlabel(ax, 'Zaman (s)');
        ylabel(ax, 'Genlik');
    end

    function plotSpectrum()
        if isempty(wavData)
        uialert(fig,'Önce veri alınmalıdır.','Uyarı');
        return;
        end
        ax.Visible = 'on';
        cla(ax);
    
        L = length(wavData);
        Y = fft(wavData);
        P2 = abs(Y/L);
        P1 = P2(1:floor(L/2)+1);
        P1(2:end-1) = 2*P1(2:end-1);
    
        % Desibel (dB) cinsine çevir (logaritmik ölçek)
        P1_dB = 20 * log10(P1 + 1e-12);  % 0 bölmesi hatası için küçük sabit ekle
    
        f = sampleRate*(0:(L/2))/L;
    
        plot(ax, f, P1_dB, 'Color', accentColor);
        title(ax, 'Frekans Spektrumu (dB)');
        xlabel(ax, 'Frekans (Hz)');
        ylabel(ax, 'Genlik (dB)');
        xlim(ax, [0 5000]); % Gerekirse sınırlandır
    end

end 

