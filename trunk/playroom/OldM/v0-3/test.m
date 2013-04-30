pause on;

set(fLogo,'CurrentCharacter','k');
figure(fLogo);
while (true)
    drawnow;
    c = get(fLogo,'CurrentCharacter');
    
    if (c == 'x')
        c = 1;
    end
    
end