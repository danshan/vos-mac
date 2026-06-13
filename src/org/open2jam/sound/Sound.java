/*
 * To change this template, choose Tools | Templates
 * and open the template in the editor.
 */
package org.open2jam.sound;

/**
 *
 * @author dttvb
 */
public interface Sound {
    
    default void prepare() throws SoundSystemException {
    }

    default void awaitPrepared() throws SoundSystemException {
    }

    SoundInstance play(SoundChannel soundChannel, float volume, float pan) throws SoundSystemException;
    
}
