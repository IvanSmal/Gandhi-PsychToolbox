function insToTxtbox(app, str)
    txtstr=sprintf('%s\n%s\n',string(get(app.InformationTextArea,'Value'))...
    , str);
    set(app.InformationTextArea,'Value',txtstr);
end